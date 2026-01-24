package wasmix.runtime;

import js.lib.*;

@:forward
abstract Memory(js.lib.webassembly.Memory) {
  public function toWASM<T:ArrayBufferView & { final length: Int; }>(u:T):BigInt {
    if (u.buffer != this.buffer) throw 'Buffer does not point to WASM memory';
    return (cast u).bounds ??= BigInt.ofInts(u.length, u.byteOffset);
  }

  public function fromWASM<T:ArrayBufferView & { final length: Int; }>(b:BigInt, ctor:(buf:ArrayBuffer, offset:Int, length:Int) -> T):T {
    return ctor(this.buffer, b.lo(), b.hi());
  }
}