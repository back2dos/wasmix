package wasmix.runtime;

import js.lib.*;

@:native('Float32Array')
extern class Float32Array implements ArrayAccess<Float32> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
	final byteOffset:Int;
	final byteLength:Int;
  
  public function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  public inline function toJS():js.lib.Float32Array {
    return cast this;
  }
}