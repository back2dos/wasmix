package wasmix.runtime;

import js.lib.*;

@:native('Int16Array')
extern class Int16Array implements ArrayAccess<Int> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
  final byteOffset:Int;
  final byteLength:Int;

  function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  function toHex():String;
  function toString():String;
  
  inline function toJS():js.lib.Int16Array {
    return cast this;
  }
}
