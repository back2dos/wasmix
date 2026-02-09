package wasmix.compiler.plugins;

class Plugin extends Common {
  final m:MethodScope;

  public function new(m:MethodScope) {
    super(@:privateAccess m.cls);
    this.m = m;
  }

  inline function type(t:Type, pos:Position) return m.cls.type(t, pos);
  inline function expr(t, expected) return m.expr(t, expected);

  public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return false;
  }

  public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return null;
  }
}