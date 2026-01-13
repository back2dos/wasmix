package wasmix;

class Compile {
  static function module(e) {
    return switch Context.typeExpr(e).expr {
      case TTypeExpr(TClassDecl(_.get() => cl)):

        final scope = new wasmix.compiler.ClassScope(e.pos, cl);
        
        final exports = scope.exports();
        
        if (Context.defined('display'))
          macro js.lib.Promise.resolve(($e:$exports));
        else {
          final module = scope.transpile();
          final blob = wasmix.wasm.Writer.toBytes(module);
          
          macro {
            wasmix.wasm.Loader.load($v{haxe.crypto.Base64.encode(blob)}, ${scope.imports.toExpr()})
              .then(function (result):$exports {
                return cast result.exports;
              });
          }
        }
      default: 
        Context.error('Only classes allowed for now', e.pos);
    }
  }
}


