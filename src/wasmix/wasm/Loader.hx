package wasmix.wasm;

class Loader {
  overload static public extern inline function load(base64:String) {
    return load(haxe.crypto.Base64.decode(base64));// TODO: optimize
  }

  overload static public extern inline function load(buf:haxe.io.Bytes) {
    return loadBuffer(buf.getData().slice(0, buf.length));
  }

  overload static public extern inline function load(buf:js.lib.ArrayBuffer) {
    return loadBuffer(buf);
  }

  static function loadBuffer(buf:js.lib.ArrayBuffer) {
    return js.lib.WebAssembly.instantiate(buf, {}).then(function(result) {
      return result.instance;
    });
  }
}