package wasmix.runtime;

import js.lib.*;

@:forward
abstract Memory(js.lib.webassembly.Memory) {
  public function toWASM<T:ArrayBufferView & { final length: Int; }>(u:T) {
    if (u.buffer != this.buffer) throw 'Buffer does not point to WASM memory';
    return BigInt.ofInts(u.length, u.byteOffset);
  }
}

class Allocator {
  
}