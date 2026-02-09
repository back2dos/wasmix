package wasmix.runtime;

class Arrays {
  static public function literal<T>(...entries:T):Array<T> return entries;
  
  static public function get<T>(array:Array<T>, index:Int):T return array[index];
  
  static public function set<T>(array:Array<T>, index:Int, value:T) return array[index] = value;
  static public function bumped(a:Array<Int>, index:Int, delta:Int) return a[index] += delta;
  static public function andBump(a:Array<Int>, index:Int, delta:Int) {
    final old = a[index];
    a[index] = old + delta;
    return old;
  }

  static public function add<T:Float>(array:Array<T>, index:Int, value:T) return array[index] += value;
  static public function mult<T:Float>(array:Array<T>, index:Int, value:T) return array[index] *= value;
  static public function sub<T:Float>(array:Array<T>, index:Int, value:T) return array[index] -= value;
  static public function div(array:Array<Float>, index:Int, value:Float) return array[index] /= value;
  static public function mod<T:Float>(array:Array<T>, index:Int, value:T) return array[index] %= value;

  static public function shl(array:Array<Int>, index:Int, value:Int) return array[index] <<= value;
  static public function shr(array:Array<Int>, index:Int, value:Int) return array[index] >>= value;
  static public function ushr(array:Array<Int>, index:Int, value:Int) return array[index] >>>= value;
  
  static public function and(array:Array<Int>, index:Int, value:Int) return array[index] &= value;
  static public function or(array:Array<Int>, index:Int, value:Int) return array[index] |= value;
  static public function xor(array:Array<Int>, index:Int, value:Int) return array[index] ^= value;
} 
