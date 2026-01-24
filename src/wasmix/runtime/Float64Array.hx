package wasmix.runtime;

import js.lib.*;

@:native('Float64Array')
extern class Float64Array implements ArrayAccess<Float> implements ArrayBufferView {
  final length:Int;
  final buffer:ArrayBuffer;
  final byteOffset:Int;
  final byteLength:Int;

  public function new(buffer:ArrayBuffer, byteOffset:Int, length:Int);

  public inline function toJS():js.lib.Float64Array {
    return cast this;
  }
}
