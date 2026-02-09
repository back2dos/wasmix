package wasmix.compiler;

import wasmix.compiler.plugins.*;

class MethodScope extends Common {
  public final field:ClassField;
  public final fn:TFunc;
  public final binOps:BinOps;
  public final locals:Locals;

  final plugins:Array<Plugin>;

  public function dup(t:ValueType) {
    final id = locals.tmp(t);
    return [LocalTee(id), LocalGet(id)];
  }

  public function new(cls, field, fn) {
    super(cls);

    this.field = field;
    this.fn = fn;
    
    if (field.name == 'memory') 
      error('Name "memory" is reserved', field.pos);
    
    this.plugins = [
      this.locals = new Locals(this),
      new Enums(this),
      new Strings(this),
      new BufferViews(this),
      new Arrays(this),
      new Switch(this),
      new While(this),
      new Classes(this),
      new UnOps(this),
      this.binOps = new BinOps(this),
    ];
  }

  var scanned = false;
  
  public function prepare() {
    if (!scanned) {
      scan(fn.expr);

      switch Context.followWithAbstracts(fn.t) {
        case _.toString() => 'Void':
        case t: returnType = cls.type(t, field.pos);
      }
      scanned = true;
    }

    return transpile;
  }
  
  public function scan(e:TypedExpr) {
    if (e != null) at(e.pos, function () switch e.expr {

      case TNew(_.get() => cl, _, args):
        for (a in args) scan(a);
          
        cls.imports.add(Constructor(cl, FunctionType.of(cl.constructor.get().type, args.length, e.t)), e.pos);
  
      case TBinop(op = OpBoolAnd | OpBoolOr, e1, e2):

        scan(e1);
        scan(e2);

        e.expr = TIf(
          e1,
          if (op == OpBoolAnd) e2 else Context.typeExpr(macro true),
          if (op == OpBoolAnd) Context.typeExpr(macro false) else e2
        );

      default:
        for (plugin in plugins) if (plugin.scan(e, scan)) return;

        e.iter(scan);
    });
  }

  function const(pos:Position, t:TConstant, expected:Null<ValueType>):Expression
    return switch [t, expected] {
      case [_, null]: [];
      case [TNull, ExternRef]: [RefNull(ExternRef)];
      case [TNull, v]: error('Cannot coerce null to ${v}', pos);
      case [TInt(i), I32]: [I32Const(i)];
      case [TInt(i), F32]: [F32Const(i)];
      case [TInt(i), F64]: [F64Const(i)];
      case [TFloat(f), F32]: [F32Const(Std.parseFloat(f))];
      case [TFloat(f), F64]: [F64Const(Std.parseFloat(f))];
      case [TBool(b), I32]: [I32Const(b ? 1 : 0)];
      case [TInt(_) | TFloat(_) | TBool(_), expected]: error('Cannot coerce ${t} to ${expected}', pos);
      case [TString(s), ExternRef]: [GlobalGet(cls.imports.findString(s))];
      default: error('Unsupported constant type', pos);
    }

  public function expr(e:TypedExpr, expected:Null<ValueType>):Expression {
    return if (e == null) [] else at(e.pos, () -> switch e.expr {// strip here?
      // case BufferViews.access(this, e) => Some(v): v.get(expected);
      case TConst(c): const(e.pos, c, expected);
      case TParenthesis(e), TMeta(_, e), TCast(e, null): expr(e, expected);
      case TBlock(el):
        final last = el.length - 1;
        [for (pos => e in el) for (i in expr(e, if (pos == last) expected else null)) i];
      case TIf(econd, eif, eelse):
        
        final cond = expr(econd, I32),
              thenBody = expr(eif, expected),
              elseBody = expr(eelse, expected);

        final blockType = if (expected == null) Empty else BlockType.Value(expected);
        cond.concat([If(blockType, thenBody, elseBody)]);

      case TNew(_.get() => cl, _, args):
        final ft = FunctionType.of(cl.constructor.get().type, args.length, e.t);
        [for (i => a in args) for (instr in expr(a, ft.args[i].valueType)) instr]
          .concat([Call(cls.imports.find(Constructor(cl, ft), e.pos))]);

      case TReturn(e):
        
        expr(e, returnType).concat([Return]);
  
      case TContinue: [Br(0)];
      case TBreak: [Br(1)];
      default: 
        for (plugin in plugins) 
          switch plugin.translate(e, expected) {
            case null:
            case v: return v;
          }
        error('Unsupported expression ${e.expr.getName()} in ${fn.expr.toString(true)}', e.pos);
    });
  }

  var returnType:Null<ValueType>;

  static final BOOL = Context.getType('Bool');
  static final INT = Context.getType('Int');

  function transpile() {    
    
    return {
      typeIndex: cls.signature([for (a in fn.args) a.v.t], fn.t, field.pos),
      locals: @:privateAccess locals.types,
      body: expr(fn.expr, null),
    }
  }
}