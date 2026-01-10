package wasmix.wasm;

class Loader {
  overload static public extern inline function load(base64:String, imports:{}) {
    return load(haxe.crypto.Base64.decode(base64), imports);// TODO: optimize
  }

  overload static public extern inline function load(buf:haxe.io.Bytes, imports:{}) {
    return loadBuffer(buf.getData().slice(0, buf.length), imports);
  }

  overload static public extern inline function load(buf:js.lib.ArrayBuffer, imports:{}) {
    return loadBuffer(buf, imports);
  }

  static function loadBuffer(buf:js.lib.ArrayBuffer, imports:{}) {
    return js.lib.WebAssembly.instantiate(buf, imports).then(function(result) {
      return result.instance;
    });
  }
}