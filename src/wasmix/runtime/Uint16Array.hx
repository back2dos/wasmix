package wasmix.runtime;

import js.lib.*;

@:native('Uint16Array')
extern class Uint16Array implements ArrayAccess<Int> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
  final byteOffset:Int;
  final byteLength:Int;

  public function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  public inline function toJS():js.lib.Uint16Array {
    return cast this;
  }
}
