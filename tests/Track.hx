import js.lib.Float32Array;

class Track {
  public static function pan(left:Float32Array, right:Float32Array, pos:Float) {
    var gainL = pos <= 0 ? 1 : 1 - pos;
    var gainR = pos >= 0 ? 1 : 1 + pos;
    for (i in 0...left.length) {
      left[i] *= gainL;
      right[i] *= gainR;
    }
  }
}