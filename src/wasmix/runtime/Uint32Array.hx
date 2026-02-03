package wasmix.runtime;

import js.lib.*;

@:native('Uint32Array')
extern class Uint32Array implements ArrayAccess<Int> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
  final byteOffset:Int;
  final byteLength:Int;

  function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  function toHex():String;
  function toString():String;
  
  inline function toJS():js.lib.Uint32Array {
    return cast this;
  }
}
