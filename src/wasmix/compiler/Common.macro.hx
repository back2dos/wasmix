package wasmix.compiler;

class Common {
  final cls:ClassScope;
  
  public function new(cls) {
    this.cls = cls;
  }

  function call(id:Int, callee:TypedExpr, ?expected:Null<ValueType>)
    return [Call(id)].concat(coerce(cls.retType(callee.t, callee.pos), expected, callee.pos));

  function strip(e:TypedExpr):TypedExpr 
    return if (e == null) null else switch e.expr {
      case TParenthesis(e), TMeta(_, e), TCast(e, _), TBlock([e]): strip(e);
      default: e;
    }

  public function coerce(from:Null<ValueType>, to:Null<ValueType>, pos:Position):Expression {
    return switch [from, to] {
      case [null, null]: [];
      case [null, v]: error('Cannot coerce Void to ${to}', pos);
      case [_, null]: [Drop];
      case [F32, F64]: [F64PromoteF32];
      case [F64, F32]: [F32DemoteF64];
      case [I32, F32]: [F32ConvertI32S];
      case [I32, F64]: [F64ConvertI32S];
      case [a, b] if (a.equals(b)): [];
      default: error('Cannot coerce ${from} to ${to}', pos);
    }
  }

  function asUpdate(e:TypedExpr) {
    return switch e.expr {
      case TBinop(OpAssignOp(op), e1, e2):
        Some({ target: e1, kind: AssignOp(e2, op) });
      case TBinop(OpAssign, e1, e2):
        Some({ target: e1, kind: Assign(e2) });
      case TUnop(op = OpIncrement | OpDecrement, postFix, target):
        Some({ target: target, kind: Bump(op == OpIncrement, postFix) });
      default: None;
    }
  }

  function asUpdateOf<T>(e:TypedExpr, getTarget:(target:TypedExpr, kind:UpdateKind)->Option<T>) {
    return switch asUpdate(e) {
      case Some(u): getTarget(u.target, u.kind);
      default: None;
    }
  }
}

@:using(wasmix.compiler.Common.UpdateTools)
enum UpdateKindOf<T> {
  Bump(up:Bool, postFix:Bool);
  Assign(value:T);
  AssignOp(value:T, op:Binop);
}

typedef UpdateKind = UpdateKindOf<TypedExpr>;

class UpdateTools {
  static public function methodName<X>(kind:UpdateKindOf<X>) {
    return switch kind {
      case Bump(up, postFix): if (postFix) 'andBump' else 'bumped';
      case Assign(_): 'set';
      case AssignOp(_, op): op.getName().toLowerCase().substr(2);
    }
  }

  static public function exprToType(kind:UpdateKind):UpdateKindOf<Type> {
    return switch kind {
      case Bump(up, postFix): Bump(up, postFix);
      case Assign(v): Assign(v.t);
      case AssignOp(v, op): AssignOp(v.t, op);
    }
  }

  overload extern static public inline function value<X>(kind:UpdateKindOf<X>, bump:(up:Bool)->X):X 
    return _value(kind, bump);

  overload extern static public inline function value(kind:UpdateKindOf<Type>):Type
    return _value(kind, _ -> Context.getType('Int'));

  overload extern static public inline function value(kind:UpdateKind):TypedExpr
    return _value(kind, up -> Context.typeExpr(macro $v{if (up) 1 else -1}));

  static function _value<X>(kind:UpdateKindOf<X>, bump:(up:Bool)->X):X {
    return switch kind {
      case Bump(up, _): bump(up);
      case Assign(v) | AssignOp(v, _): v;
    }
  }
}