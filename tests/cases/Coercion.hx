package cases;

import wasmix.runtime.*;

function main() {
  final coercion = wasmix.Compile.module(Coercion, { sync: true });
  final a = new Allocator(coercion.memory);

  Assert.that(coercion.vars() == 8);
  
  Assert.that(Std.string(coercion.f32(a.f32(5), a.f64(4))) == '1,2,3,4.5,5.5');
  Assert.that(Std.string(coercion.f64(a.f64(5), a.s32(4))) == '10,20.5,30,20.375,101.25');
}

class Coercion {
  static public function f32(f:Float32Array, d:Float64Array) {
    f[0] = 1;
    f[1] = 2.0;
    
    var a:Float32 = 3;
    var b:Float32 = 4.5;

    f[2] = a;
    f[3] = b;
    d[0] = 6.5;
    f[4] = d[0];
    f[4] -= 1;
    f[3] *= 1;

    return f;
  }

  static public function f64(f:Float64Array, i:Int32Array) {
    f[0] = 10;
    f[1] = 20.5;
    var a:Float = 30;
    var b:Float = 40.75;
    f[2] = a;
    f[3] = b;
    i[0] = 100;
    f[4] = i[0];
    f[4] += 1.25;
    f[3] /= 2;

    return f;
  }

  static public function vars() {
    var a:Float32 = 1.0;
    var b:Float32 = 2;
    var c:Float = 3;
    a = b;
    b = c;
    var d = b -= 1.0;
    a = 1;
    return a + b + c + d;
  }


}