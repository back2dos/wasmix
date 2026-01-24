package wasmix.wasm;

import js.lib.webassembly.*;
import js.lib.*;
import haxe.io.Bytes;

class Loader {
  static public function loadSync(buf:Source, imports:{}) 
    return new Instance(new js.lib.webassembly.Module(buf), imports);

  static public function load(buf:Source, imports:{}) 
    return js.lib.WebAssembly.instantiate(buf, imports).then(r -> r.instance);
}

@:transitive
abstract Source(BufferSource) from BufferSource to BufferSource {
  inline function new(v) this = v;

  @:from static function ofString(base64:String)
    return new Source({
      #if nodejs
        js.node.Buffer.from(base64, 'base64');
      #else
        final bin = js.Browser.window.atob(base64);
        final bytes = new Uint8Array(bin.length);
        
        for (i in 0...bin.length) bytes[i] = bin.charCodeAt(i) & 0xFF;
        
        bytes;
      #end
    });

  @:from static function ofBytes(bytes:Bytes)
    return new Source(bytes.getData().slice(0, bytes.length));
}