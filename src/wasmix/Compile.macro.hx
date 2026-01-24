package wasmix;

import wasmix.compiler.*;

class Compile {
  static function module(e, ?options:Expr) {
    final display = Context.defined('display');

    final options:CompilerOptions = switch options {
      case macro null: { };
      default:
        options = macro @:pos(options.pos) ($options:wasmix.compiler.CompilerOptions);
        if (display && Context.containsDisplayPosition(options.pos))
          return options;

        switch TypedExprs.strip(Context.typeExpr(options)).expr {
          case TObjectDecl(fields):
            var o:CompilerOptions = {};
            for (f in fields) 
              Reflect.setField(o, f.name, switch TypedExprs.strip(f.expr).expr {
                case TConst(TBool(b)): b;
                case v:
                  Context.error('Boolean constant expected', f.expr.pos);
              });
            o;
          default:
            Context.error('Invalid options', options.pos);
        }
    }

    return switch Context.typeExpr(e).expr {
      case TTypeExpr(TClassDecl(_.get() => cl)):

        final scope = new wasmix.compiler.ClassScope(e.pos, cl);        
        final exports = scope.exportsShape();

        if (display)
          if (options.sync)
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

          if (options.sync)
            export(macro wasmix.wasm.Loader.loadSync($v{base64}, ${imports}));
          else
            macro wasmix.wasm.Loader.load($v{base64}, ${imports}).then(inst -> ${export(macro inst)});
        }
      default: 
        Context.error('Only classes allowed for now', e.pos);
    }
  }
}


