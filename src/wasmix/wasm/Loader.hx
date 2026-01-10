package wasmix.wasm;

import js.lib.*;
import haxe.io.Bytes;

class Loader {
  overload static public extern inline function load(base64:String, imports:{}) 
    return load(haxe.crypto.Base64.decode(base64), imports);// TODO: optimize

  overload static public extern inline function load(bytes:Bytes, imports:{}) 
    return loadBuffer(bufOfBytes(bytes), imports);

  overload static public extern inline function load(buf:ArrayBuffer, imports:{}) 
    return loadBuffer(buf, imports);

  static function bufOfBytes(bytes:Bytes):ArrayBuffer
    return bytes.getData().slice(0, bytes.length);

  static function decode(base64:String):ArrayBuffer {
    #if nodejs
      return js.node.Buffer.from(base64, 'base64').buffer;
    #else
      final bin = js.Browser.window.atob(base64);
      final bytes = new Uint8Array(bin.length);
      
      for (i in 0...bin.length) bytes[i] = bin.charCodeAt(i) & 0xFF;
      
      return bytes.buffer;
    #end
  }

  static function loadBuffer(buf:ArrayBuffer, imports:{}) 
    return js.lib.WebAssembly.instantiate(buf, imports).then(r -> r.instance);
}