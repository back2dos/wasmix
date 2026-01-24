package cases;

import wasmix.runtime.*;

function main() {
  final coercion = wasmix.Compile.module(Coercion, true);
  Assert.that(coercion.vars() == 8);
}

class Coercion {
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

  static public function buffers(i8:Int8Array, u8:Uint8Array, i16:Int16Array, u16:Uint16Array, i32:Int32Array, u32:Uint32Array, f32:Float32Array, f64:Float64Array):Float {

    i8[0] = 1;
    u8[0] = 2;
    i16[0] = 3;
    u16[0] = 4;
    i32[0] = 5;
    u32[0] = 6;
    f32[0] = 7;
    // f64[0] = 8.0;

    return f32[0] + i8[0] + u8[0] + i16[0] + u16[0] + i32[0] + u32[0] + f64[0];
  }
}