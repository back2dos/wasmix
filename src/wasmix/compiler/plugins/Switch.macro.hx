package wasmix.compiler.plugins;

class Switch extends Plugin {
  var varIdCounter = 0;

  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case TSwitch(target, cases, eDefault):
        final tmp = '_wasmix_tmp_${varIdCounter++}';// TODO: only temp var if switch target is not a var

        var cases = cases.copy();
        cases.reverse();

        var tree = switch eDefault {// TODO: avoid tree for dense switches (e.g. over enum indices)
          case null: 
            Context.storeTypedExpr(cases.pop().expr);
          default: 
            Context.storeTypedExpr(eDefault);
        }

        for (c in cases) {
          var checks = [for (v in c.values) macro $i{tmp} == ${Context.storeTypedExpr(v)}];
          var check = checks.pop();

          while (checks.length > 0) 
            check = macro $check || ${checks.pop()};
          
          tree = macro if ($check) ${Context.storeTypedExpr(c.expr)} else $tree;
        }

        final targetType = Context.toComplexType(Context.followWithAbstracts(target.t));

        var tTree = Context.typeExpr(macro @:pos(e.pos) {
          var $tmp:$targetType = cast ${Context.storeTypedExpr(target)};
          $tree;
        });

        e.expr = tTree.expr;

        rec(e);
        
        true;
      default: false;
    }
  }
}