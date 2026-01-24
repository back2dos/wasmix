package wasmix.compiler;

class TypedExprs {
  static public function strip(e:TypedExpr):TypedExpr 
    return if (e == null) null else switch e.expr {
      case TParenthesis(e), TMeta(_, e), TCast(e, _), TBlock([e]): strip(e);
      default: e;
    }
}