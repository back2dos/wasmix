package wasmix;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.*;
import wasmix.wasm.Writer;
import wasmix.wasm.Data;

using haxe.macro.Tools;

class Compile {
  static function module(e:Expr) {
    return switch Context.typeExpr(e).expr {
      case TTypeExpr(TClassDecl(_.get() => cl)):
        final scope = new ClassScope(e.pos, cl);
        
        final module = scope.transpile();

        final exports = scope.exports();
        
        final blob = Writer.toBytes(module);
        
        macro {
          wasmix.wasm.Loader.load($v{haxe.crypto.Base64.encode(blob)})
            .then(function (result):$exports {
              return cast result.exports;
            });
        }
      default: 
        Context.error('Only classes allowed for now', e.pos);
    }
  }
}

private class ClassScope {

  final methods = new Array<MethodScope>();
  final methodIndices = new Map<String, Int>();
  final types = new Array<FunctionType>();
  final typeIndices = new Map<String, Int>();

  public function new(pos:Position, cl:ClassType) {

    for (f in cl.statics.get()) switch f.kind {
      case FMethod(MethNormal) if (f.isPublic):
        
        methodIndices[f.name] = methods.length;

        switch f.expr() {
          case { expr: TFunction(fn) }:
            methods.push(new MethodScope(this, f, fn));
          default:
            throw 'assert';
        }
      default:
    }
  }

  public inline function getFunctionId(name:String) {
    return methodIndices[name];
  }

  public function signature(args:Array<Type>, ret:Type, pos:Position) {
    return 
      typeIndices[args.concat([ret]).map(t -> t.toString()).join(' -> ')] ??= (
        types.push({
          params: [for (a in args) type(a, pos)],
          results: switch Context.followWithAbstracts(ret) {
            case TAbstract(_.toString() => 'Void', _): [];
            case t: [type(t, pos)];
          },
        }) - 1
      );
  }

  public function transpile():Module {
    return {
      functions: [for (method in methods) method.transpile()],
      exports: [for (method in methods) {
        name: method.field.name,
        kind: ExportFunction(methodIndices[method.field.name])
      }],
      types: types,
    }
  }

  public function type(t:Type, pos:Position) {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(a, _): 
        switch a.toString() {
          case "Bool" | "Int": I32;
          case "Float": F64;
          default: Context.error('Unsupported type ${a.toString()}', pos);
        }
      case TFun(args, ret): FuncRef;
      default: Context.error('Unsupported type ${t.toString()}', pos);
    }
  }

  public function exports() {
    return ComplexType.TAnonymous([for (method in methods) {
      name: method.field.name,
      pos: method.field.pos,
      kind: FFun({
        args: [
          for (a in method.fn.args) {
            name: a.v.name,
            type: Context.toComplexType(a.v.t),
          }
        ],
        ret: Context.toComplexType(method.fn.t),
      }),
    }]);
  }
}

private class MethodScope {
  public final field:ClassField;
  public final fn:TFunc;
  final cls:ClassScope;
  final varIds = new Map<Int, Int>();
  final locals = new Array<ValueType>();

  public function new(cls, field, fn) {
    this.cls = cls;
    this.field = field;
    this.fn = fn;
    var varIdCounter = 0;

    for (a in fn.args) varIds[a.v.id] = varIdCounter++;

    (function scan(e:TypedExpr) {
      switch e.expr {
        case TVar(v, _): 
          varIds[v.id] = varIdCounter++;
          locals.push(cls.type(v.t, e.pos));
        default:
          e.iter(scan);
      }
    })(fn.expr);
  }

  function const(pos:Position, t:TConstant):Expression {
    return switch t {
      case TInt(i):
        [Instruction.I32Const(i)];
      case TFloat(f):
        [Instruction.F64Const(Std.parseFloat(f))];
      case TBool(b):
        [Instruction.I32Const(b ? 1 : 0)];
      default:
        Context.error('Unsupported constant type', pos);
    }
  }

  function expr(e:TypedExpr):Expression {
    return switch e.expr {
      case TConst(c): const(e.pos, c);
      case TLocal(v): [LocalGet(varIds[v.id])];
      case TVar(v, e): expr(e).concat([LocalSet(varIds[v.id])]);
      case TParenthesis(e), TMeta(_, e), TCast(e, _): expr(e);
      case TWhile(econd, e, normalWhile):

        [Block(
          Empty, 
          [Loop(
            Empty, 
            if (normalWhile)
              expr(econd)
                .concat([
                  I32Eqz,
                  BrIf(1),
                ])
                .concat(expr(e))
                .concat([Br(0)])
            else
              expr(e)
                .concat(expr(econd))
                .concat([If(Empty, [Br(0)], [Br(1)])])
          )]
        )];

      case TBlock(el):
        var result:Expression = [];
        for (e in el) result = result.concat(expr(e));
        result;
      case TIf(econd, eif, eelse):
        
        final cond = expr(econd),
              thenBody = expr(eif),
              elseBody = eelse != null ? expr(eelse) : [];

        cond.concat([If(ValueType(I32), thenBody, elseBody)]);

      case TReturn(e):
        expr(e).concat([Return]);
      case TCall(e, args):
        switch e.expr {
          case TField(_, FStatic(c, cf)): // TODO: check class
            final id = cls.getFunctionId(cf.get().name);
            var ret = [];
            for (a in args) ret = ret.concat(expr(a));
            ret.concat([Call(id)]);
          default:
            switch e.t {
              case TFun(params, ret):
                final id = cls.signature([for (a in params) a.t], ret, e.pos);
                var ret = [];
                for (a in args) ret = ret.concat(expr(a));
                ret.concat([CallIndirect(id)]);
              default: throw 'assert';
            }
        }
      case TUnop(op, postFix, e):
        switch op {
          case OpIncrement | OpDecrement:
            switch e.expr {
              case TLocal(v):
                final id = varIds[v.id];
                final op = op == OpIncrement ? I32Add : I32Sub;
                if (postFix) [
                  LocalGet(id),
                  LocalGet(id),
                  I32Const(1),
                  op,
                  LocalSet(id),
                ]
                else [
                  LocalGet(id),
                  I32Const(1),
                  op,
                  LocalTee(id),
                ];
              default:
                Context.error('Operand must be a local variable', e.pos);
            }
          case OpNot:
            expr(e).concat([I32Eqz]);
          case OpNeg:
            expr(e).concat([I32Const(0), I32Sub]);
          case OpNegBits:
            expr(e).concat([I32Const(-1), I32Xor]);
          case OpSpread:
            Context.error('Spread operator not supported', e.pos);
        }
      case TBinop(op, e1, e2):
        final expr1 = expr(e1);
        final expr2 = expr(e2);
        
        function make(op:Binop)
          return expr1.concat(expr2).concat([switch op {
            case OpAdd: I32Add;
            case OpSub: I32Sub;
            case OpMult: I32Mul;
            case OpDiv: I32DivS;
            case OpMod: I32RemS;
            case OpEq: I32Eq;
            case OpNotEq: I32Ne;
            case OpLt: I32LtS;
            case OpLte: I32LeS;
            case OpGt: I32GtS;
            case OpGte: I32GeS;
            case OpAnd: I32And;
            case OpOr: I32Or;
            case OpShl: I32Shl;
            case OpShr: I32ShrS;
            case OpUShr: I32ShrU;
            case OpXor: I32Xor;
            default: Context.error('Unsupported binary operator ${op.getName()}', e.pos);
          }]);

        switch op {
          case OpAssignOp(op):
            switch e1.expr {
              case TLocal(v):
                make(op).concat([LocalTee(varIds[v.id])]);
              default:
                Context.error('LHS must be a local variable', e1.pos);
            }
          default: make(op);
        }
      default: Context.error('Unsupported expression ${e.expr.getName()}', e.pos);
    }
  }

  public function transpile():Function {
    return {
      typeIndex: cls.signature([for (a in fn.args) a.v.t], fn.t, field.pos),
      locals: locals,
      body: expr(fn.expr),
    };
  }
}