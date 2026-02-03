package cases;

import wasmix.Compile;
import wasmix.runtime.*;

function main() {
  final mod = Compile.module(TypedArrays);
  final alloc = new Allocator(mod.memory);

  // Pre-create some arrays to pass in
  final f32 = alloc.f32(5);
  final i32 = alloc.s32(6);
  final u8 = alloc.u8(8);

  mod.basicOperations(f32);
  mod.compoundAssignments(i32);
  mod.bitwiseOps(u8);
  mod.createAndFill(alloc);
  mod.copyAndTransform(alloc);
  mod.mixedTypes(alloc);
}

class TypedArrays {

  static public function basicOperations(arr:Float32Array) {
    // Set values, read them back, do arithmetic
    arr[0] = 1.5;
    arr[1] = 2.5;
    arr[2] = arr[0] + arr[1];
    arr[3] = arr[2] * 2;
    arr[4] = arr[3] - arr[0];

    Assert.that(arr.toString() == "1.5,2.5,4,8,6.5");
  }

  static public function compoundAssignments(arr:Int32Array) {
    // Test +=, -=, *=, /=, %=
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 100;
    arr[3] = 15;
    arr[4] = 8;
    arr[5] = 3;

    arr[0] += 5;      // 10 + 5 = 15
    arr[1] -= 7;      // 20 - 7 = 13
    arr[2] *= 2;      // 100 * 2 = 200
    arr[3] = Std.int(arr[3] / 3);  // 15 / 3 = 5
    arr[4] %= 3;      // 8 % 3 = 2
    arr[5] = arr[0] + arr[1] * arr[4]; // 15 + 13 * 2 = 41

    Assert.that(arr.toString() == "15,13,200,5,2,41");
  }

  static public function bitwiseOps(arr:Uint8Array) {
    // Test bitwise operations
    arr[0] = 0xFF;
    arr[1] = 0x0F;
    arr[2] = arr[0] & arr[1];  // 0xFF & 0x0F = 0x0F = 15
    arr[3] = arr[0] | 0x00;    // 0xFF | 0x00 = 0xFF = 255
    arr[4] = arr[1] ^ 0xFF;    // 0x0F ^ 0xFF = 0xF0 = 240
    arr[5] = 1 << 4;           // 16
    arr[6] = 128 >> 2;         // 32
    arr[7] = arr[5] + arr[6];  // 16 + 32 = 48

    Assert.that(arr.toString() == "255,15,15,255,240,16,32,48");
  }

  static public function createAndFill(alloc:Allocator) {
    // Create arrays inside the function and fill with patterns
    final f64 = alloc.f64(4);
    f64[0] = 1.1;
    f64[1] = 2.2;
    f64[2] = 3.3;
    f64[3] = f64[0] + f64[1] + f64[2];  // 6.6

    Assert.that(f64.toString() == "1.1,2.2,3.3,6.6");

    final u16 = alloc.u16(5);
    u16[0] = 1000;
    u16[1] = 2000;
    u16[2] = 3000;
    u16[3] = u16[0] + u16[1];  // 3000
    u16[4] = u16[2] - u16[0];  // 2000

    Assert.that(u16.toString() == "1000,2000,3000,3000,2000");

    alloc.free(f64);
    alloc.free(u16);
  }

  static public function copyAndTransform(alloc:Allocator) {
    // Create source, transform into destination
    final src = alloc.s32(4);
    final dst = alloc.s32(4);

    src[0] = 2;
    src[1] = 4;
    src[2] = 6;
    src[3] = 8;

    // Square each element
    dst[0] = src[0] * src[0];
    dst[1] = src[1] * src[1];
    dst[2] = src[2] * src[2];
    dst[3] = src[3] * src[3];

    Assert.that(dst.toString() == "4,16,36,64");

    // Modify in place with compound assignments
    dst[0] += 1;
    dst[1] -= 1;
    dst[2] *= 2;
    dst[3] = Std.int(dst[3] / 2);

    Assert.that(dst.toString() == "5,15,72,32");

    alloc.free(src);
    alloc.free(dst);
  }

  static public function mixedTypes(alloc:Allocator) {
    // Work with multiple array types, do conversions
    final ints = alloc.s32(3);
    final floats = alloc.f32(3);

    ints[0] = 10;
    ints[1] = 20;
    ints[2] = 30;

    // Convert ints to floats and add 0.5
    floats[0] = ints[0] + 0.5;
    floats[1] = ints[1] + 0.5;

    floats[2] += ints[2];
    floats[2] *= ints[0] + ints[1];

    Assert.that(floats.toString() == "10.5,20.5,900");

    // Chain of operations
    final result = alloc.s32(4);
    result[0] = ints[0] + ints[1];           // 30
    result[1] = ints[1] * ints[2];           // 600
    result[2] = Std.int(result[1] / result[0]); // 600 / 30 = 20
    result[3] = result[0] + result[1] + result[2]; // 30 + 600 + 20 = 650

    Assert.that(result.toString() == "30,600,20,650");

    alloc.free(ints);
    alloc.free(floats);
    alloc.free(result);
  }
}
