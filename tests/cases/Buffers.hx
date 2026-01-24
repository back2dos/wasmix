package cases;

import wasmix.Compile;

function main() {
  final buffers = Compile.module(Buffers, true);
  final ret = buffers.test();
  Assert.that(ret == 123);
}

class Buffers {
  static public function test() {
    return 123;
  }
}