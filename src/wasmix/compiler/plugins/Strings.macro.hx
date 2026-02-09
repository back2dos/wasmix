package wasmix.compiler.plugins;

class Strings extends Plugin {
  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case TBinop(op, e1, e2) if (isString(e1) || isString(e2)):

        rec(e1);
        rec(e2);

        function make(op:Binop) {
          final method = op.getName().toLowerCase().substr(2);
          final ret = Context.typeExpr(macro @:pos(e.pos) wasmix.runtime.Strings.$method(${Context.storeTypedExpr(e1)}, ${Context.storeTypedExpr(e2)}));
          rec(ret);
          return ret;
        }

        switch op {
          case OpAssign:
          case OpAssignOp(op):
            e.expr = TBinop(OpAssign, e1, make(op));
          default:
            e.expr = make(op).expr;
        }
        true;

      case TConst(TString(s)):
        cls.imports.addString(s);
        true;
  
      default: false;
    }
  }

  static function isString(e:TypedExpr) {
    return Context.followWithAbstracts(e.t).match(TInst(_.toString() => 'String', _));
  }
}