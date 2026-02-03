package wasmix.runtime;

import js.lib.*;

@:native('Int32Array')
extern class Int32Array implements ArrayAccess<Int> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
  final byteOffset:Int;
  final byteLength:Int;

  function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  function toHex():String;
  function toString():String;
  
  inline function toJS():js.lib.Int32Array {
    return cast this;
  }
}
