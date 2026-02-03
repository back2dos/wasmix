package wasmix.runtime;

import js.lib.*;

@:native('Float32Array')
extern class Float32Array implements ArrayAccess<Float32> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
	final byteOffset:Int;
	final byteLength:Int;
  
  function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  function toHex():String;
  function toString():String;
  
  inline function toJS():js.lib.Float32Array {
    return cast this;
  }
}