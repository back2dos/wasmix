package wasmix.compiler;

import wasmix.compiler.Ops;

class MethodScope {
  public final field:ClassField;
  public final fn:TFunc;

  final cls:ClassScope;
  
  var varIdCounter = 0;

  final varIds = new Map<Int, Int>();
  final locals = new Array<ValueType>();
  final tmpIds = new Map<ValueType, Int>();

  function tmp(t:ValueType) {
    return tmpIds[t] ??= {
      final id = varIdCounter++;
      locals.push(t);
      id;
    }
  }

  function dup(t:ValueType) {
    final id = tmp(t);
    return [LocalTee(id), LocalGet(id)];
  }

  public function new(cls, field, fn) {
    this.cls = cls;
    this.field = field;
    this.fn = fn;
    
    if (field.name == 'memory') 
      Context.error('Name "memory" is reserved', field.pos);
    
    for (a in fn.args) varIds[a.v.id] = varIdCounter++;
  }

  var scanned = false;
  function scan(e:TypedExpr) {
    if (e != null) switch e.expr {
      case TVar(v, init): 
        
        varIds[v.id] = varIdCounter++;
        locals.push(cls.type(v.t, e.pos));
        scan(init);

      case TField(_, FEnum(_.get() => enm, ef)):

        cls.imports.addStatic(enm, ef, e.t, e.pos);

      case TCall({ expr: TField(_, FStatic(_.get() => c, _.get() => f)), t: sig }, args) if (!cls.isSelf(c)):

        for (a in args) scan(a);
        cls.imports.addStatic(c, f, sig, e.pos);

      case TSwitch(target, cases, eDefault):
        e.iter(scan);

        final tmp = '_wasmix_tmp_${varIdCounter}';// TODO: only temp var if switch target is not a temp var

        var cases = cases.copy();
        cases.reverse();

        var tree = switch eDefault {// TODO: avoid tree for dense switches (e.g. over enum indices)
          case null: 
            Context.storeTypedExpr(cases.pop().expr);
          default: 
            Context.storeTypedExpr(eDefault);
        }

        for (c in cases) {
          var checks = [for (v in c.values) macro $i{tmp} == ${Context.storeTypedExpr(v)}];
          var check = checks.pop();

          while (checks.length > 0) 
            check = macro $check || ${checks.pop()};
          
          tree = macro if ($check) ${Context.storeTypedExpr(c.expr)} else $tree;
        }

        final targetType = Context.toComplexType(Context.followWithAbstracts(target.t));

        var tTree = Context.typeExpr(macro @:pos(e.pos) {
          var $tmp:$targetType = cast ${Context.storeTypedExpr(target)};
          $tree;
        });

        e.expr = tTree.expr;

        scan(e);
      case TEnumIndex(e):
        scan(e);
        cls.imports.addStaticByName('wasmix.runtime.Enums', 'index', INDEX);
      case TEnumParameter(target, _):
        scan(target);
        cls.imports.addStaticByName('wasmix.runtime.Enums', 'param', enumParam(e.t));
      default:

        e.iter(scan);
    }
  }

  function enumParam(t:Type) {
    return PARAM.type.applyTypeParameters(PARAM.params, [t]);
  }

  static final PARAM = Imports.resolveStaticField('wasmix.runtime.Enums', 'param');
  static final INDEX = Context.typeof(macro wasmix.runtime.Enums.index);

  function const(pos:Position, t:TConstant):Expression
    return switch t {
      case TInt(i): [I32Const(i)];
      case TFloat(f): [F64Const(Std.parseFloat(f))];
      case TBool(b): [I32Const(b ? 1 : 0)];
      default: Context.error('Unsupported constant type', pos);
    }

  function strip(e:TypedExpr):TypedExpr 
    return if (e == null) null else switch e.expr {
      case TParenthesis(e), TMeta(_, e), TCast(e, _), TBlock([e]): strip(e);
      default: e;
    }

  function expr(e:TypedExpr):Expression {
    return if (e == null) [] else switch e.expr {// strip here?
      case TConst(c): const(e.pos, c);
      case TLocal(v): [LocalGet(varIds[v.id])];
      case TVar(v, e): 
        if (e == null) [];
        else expr(e).concat([LocalSet(varIds[v.id])]);
      case TParenthesis(e), TMeta(_, e), TCast(e, _): expr(e);
      case TEnumIndex(e):
        expr(e).concat([Call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'index', INDEX))]);
      case TEnumParameter(target, _, index):
        expr(target).concat([I32Const(index),Call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'param', enumParam(e.t)))]);
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
              elseBody = expr(eelse);

        final blockType = if (eelse != null) BlockType.ValueType(cls.type(eif.t, e.pos)) else Empty;
        cond.concat([If(blockType, thenBody, elseBody)]);

      case TReturn(e):
        expr(e).concat([Return]);
      case TField(_, FEnum(_.get() => enm, ef)):
        [Call(cls.imports.findStatic(enm, ef, e.t))];
      case TField(target, FInstance(BufferView.getType(_) => Some(type), _, _.get() => { name: 'length' })):
        expr(target).concat([I64Const(32), I64ShrU, I32WrapI64]);
      case TCall(e, args):
        switch e.expr {
          case TField({ t: sig }, FStatic(_.get() => c, _.get() => cf)): // TODO: check class
            var ret = [];

            for (a in args) ret = ret.concat(expr(a));
            
            if (cls.isSelf(c)) {
              final id = cls.getFunctionId(cf.name);
              ret.concat([Call(id)]);
            } else {
              final id = cls.imports.findStatic(c, cf, sig);
              ret.concat([Call(id)]);
            }
          case TField(_, FEnum(_.get() => enm, ef)):
            var ret = [];

            for (a in args) ret = ret.concat(expr(a));

            final id = cls.imports.findStatic(enm, ef, e.t);
            ret.concat([Call(id)]);
          default:
            Context.error('Invalid call target $e', e.pos);
        }
      case TContinue: [Br(0)];
      case TBreak: [Br(1)];
      case TUnop(op, postFix, e):
        switch op {
          case OpIncrement | OpDecrement:
            switch e.expr {
              case TLocal(v):
                final id = varIds[v.id],
                      op = op == OpIncrement ? I32Add : I32Sub;

                if (postFix) 
                  [LocalGet(id), LocalGet(id), I32Const(1), op, LocalSet(id)];
                else 
                  [LocalGet(id), I32Const(1), op, LocalTee(id)];
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
          case OpAssign:
            switch e1 {
              case { expr: TLocal(v) }:
                expr(e2).concat([LocalTee(varIds[v.id])]);
              case BufferView.access(_) => Some(v):
                v.offset(expr)
                  .concat(expr(e2))
                  .concat([BufferView.store(v.t)]);    
              default:
                Context.error('LHS must be a local variable in assignment', e1.pos);
            }
          case OpAssignOp(op):
            switch e1 {
              case { expr: TLocal(v) }:
                make(op).concat([LocalTee(varIds[v.id])]);
              case BufferView.access(_) => Some(v):
                v.offset(expr)
                  .concat(dup(I32))
                  .concat([BufferView.load(v.t)])
                  .concat(expr(e2))
                  .concat([binOp(op, e1, e2)])
                  .concat([BufferView.store(v.t)]);    
              default:
                Context.error('LHS must be a local variable', e1.pos);
            }
          default: make(op);
        }
      default: 
        switch BufferView.access(e) {
          case Some(v):
            v.offset(expr).concat([BufferView.load(v.t)]);
          default:
            Context.error('Unsupported expression ${e.expr.getName()} in ${fn.expr.toString(true)}', e.pos);
        }
    }
  }

  static final BOOL = Context.getType('Bool');
  static final INT = Context.getType('Int');

  public function transpile():Function {
    if (!scanned) {
      scan(fn.expr);
      scanned = true;
    }
    return {
      typeIndex: cls.signature([for (a in fn.args) a.v.t], fn.t, field.pos),
      locals: locals,
      body: expr(fn.expr),
    }
  }
}