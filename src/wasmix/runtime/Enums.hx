package wasmix.runtime;

class Enums {
  static public function index(e:EnumValue):Int {
    return inline Type.enumIndex(e);
  }
  
  static public function param<T>(e:EnumValue, index:Int):T {
    #if js_enums_as_arrays
    return (cast e)[index + 2];
    #else
    return Type.enumParameters(e)[index];// TODO: optimize
    #end
  }
} 
