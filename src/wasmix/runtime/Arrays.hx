package wasmix.runtime;

class Arrays {
  static public function literal<T>(...entries:T):Array<T> return entries;
  static public function get<T>(array:Array<T>, index:Int):T return array[index];
} 
