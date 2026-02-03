package wasmix.runtime;

class Strings {
  static public function eq(a:String, b:String) return a == b;
  static public function noteq(a:String, b:String) return a != b;
  static public function lt(a:String, b:String) return a < b;
  static public function lte(a:String, b:String) return a <= b;
  static public function gt(a:String, b:String) return a > b;
  static public function gte(a:String, b:String) return a >= b;
  static public function add(a:String, b:String) return a + b;
} 
