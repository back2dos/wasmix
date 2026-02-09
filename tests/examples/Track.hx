package examples;

import wasmix.runtime.*;

class Track {
  static public function pan(left:Float32Array, right:Float32Array, pos:Float) {
    var gainL:Float32 = pos <= .0 ? 1.0 : 1.0 + pos;
    var gainR:Float32 = pos >= .0 ? 1.0 : 1.0 + pos;
    
    for (i in 0...left.length) left[i] *= gainL;
    for (i in 0...right.length) right[i] *= gainR;
  }

  static public function foo() {
    return 5;
  }
}