package wasmix.runtime;

@:coreType abstract Float32 from Float to Float from Int {
  @:op(a + b) function add(b:Float32):Float32;
  
  @:op(a - b) function sub(b:Float32):Float32;
  @:op(a - b) static function subL(a:Float32, b:Float32):Float32;
  
  @:op(a * b) function mul(b:Float32):Float32;
  
  @:op(a / b) function div(b:Float32):Float32;
  @:op(a / b) static function divL(a:Float32, b:Float32):Float32;

  @:op(a == b) function eq(b:Float32):Bool;
  @:op(a != b) function ne(b:Float32):Bool;
  
  @:op(a < b) function lt(b:Float32):Bool;
  @:op(a < b) static function ltL(a:Float32, b:Float32):Bool;
  @:op(a <= b) function le(b:Float32):Bool;
  @:op(a <= b) static function leL(a:Float32, b:Float32):Bool;
  @:op(a > b) function gt(b:Float32):Bool;
  @:op(a > b) static function gtL(a:Float32, b:Float32):Bool;

  @:op(a >= b) function ge(b:Float32):Bool;
  @:op(a >= b) static function geL(a:Float32, b:Float32):Bool;

  public inline function max(that:Float32) {
    return if (this > that) this else that;
  }
  public inline function min(that:Float32) {
    return if (this < that) this else that;
  }
}