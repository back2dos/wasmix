package wasmix.compiler;

import wasmix.compiler.Ops;

class MethodScope {
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

        final blockType = if (eelse != null) ValueType(cls.type(eif.t, e.pos)) else Empty;
        cond.concat([If(blockType, thenBody, elseBody)]);

      case TReturn(e):
        expr(e).concat([Return]);
      case TCall(e, args):
        switch e.expr {
          case TField(_, FStatic(_.get() => c, _.get() => cf)): // TODO: check class
            var ret = [];

            for (a in args) ret = ret.concat(expr(a));
            
            if (ClassScope.classId(c) == cls.name) {
              final id = cls.getFunctionId(cf.name);
              ret.concat([Call(id)]);
            } else {
              final id = cls.imports.addStatic(c, cf);
              ret.concat([CallIndirect(id)]);
            }
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
      case TContinue: [Br(0)];
      case TBreak: [Br(1)];
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

        function make(op:Binop) 
          return expr(e1).concat(expr(e2)).concat([binOp(op, e1, e2)]);

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