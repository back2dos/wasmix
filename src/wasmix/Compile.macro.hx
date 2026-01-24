package wasmix;

class Compile {
  static function module(e, sync:Bool = false) {
    return switch Context.typeExpr(e).expr {
      case TTypeExpr(TClassDecl(_.get() => cl)):

        final exports = macro : { final memory:String; };
        final scope = new wasmix.compiler.ClassScope(e.pos, cl);
        
        final exports = scope.exportsShape();
        

        if (Context.defined('display'))
          if (sync)
            macro (cast $e:$exports);
          else
            macro js.lib.Promise.resolve((cast $e:$exports));
        else {
          final base64 = haxe.crypto.Base64.encode(
            wasmix.wasm.Writer.toBytes(scope.transpile())
          );

          final imports = scope.imports.toExpr();

          function export(inst:Expr)
            return macro (cast ${scope.exports(macro $inst.exports)}:$exports);

          if (sync)
            export(macro wasmix.wasm.Loader.loadSync($v{base64}, ${imports}));
          else
            macro wasmix.wasm.Loader.load($v{base64}, ${imports}).then(inst -> ${export(macro inst)});
        }
      default: 
        Context.error('Only classes allowed for now', e.pos);
    }
  }
}


