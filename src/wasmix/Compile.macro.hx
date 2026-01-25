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
          if (options.async)
            macro js.lib.Promise.resolve((cast $e:$exports));
          else
            macro (cast $e:$exports);
        else {
          final base64 = haxe.crypto.Base64.encode(
            wasmix.wasm.Writer.toBytes(scope.transpile())
          );

          final imports = scope.imports.toExpr();

          function export(inst:Expr)
            return macro (cast ${scope.exports(macro $inst.exports)}:$exports);

          if (options.skip) {
            var withoutMemory = switch exports {
              case TAnonymous(fields): ComplexType.TAnonymous([for (f in fields) if (f.name != 'memory') f]);// for DCE
              default: throw 'assert';
            }
            final fake = macro (cast js.lib.Object.assign({ memory: new js.lib.webassembly.Memory({ initial: 1 }) }, ($e:$withoutMemory)):$exports);
            if (options.async) macro js.lib.Promise.resolve(fake);
            else fake;
          }
          else 
            if (options.async)
              macro wasmix.wasm.Loader.load($v{base64}, ${imports}).then(inst -> ${export(macro inst)});
            else
              export(macro wasmix.wasm.Loader.loadSync($v{base64}, ${imports}));
        }
      default: 
        Context.error('Only classes allowed for now', e.pos);
    }
  }
}


