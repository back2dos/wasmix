package wasmix.compiler.plugins;

class While extends Plugin {

  function exprInverted(e:TypedExpr):Expression {
    return switch strip(e).expr {
      case TBinop(op, e1, e2):
        final inverted = switch op {
          case OpLt: OpGte;
          case OpLte: OpGt;
          case OpGt: OpLte;
          case OpGte: OpLt;
          case OpEq: OpNotEq;
          case OpNotEq: OpEq;
          default: null;
        };
        if (inverted != null)
          m.binOps.make(inverted, e1, e2, I32, e.pos);
        else
          expr(e, I32).concat([I32Eqz]);
      case TUnop(OpNot, false, inner):
        expr(inner, I32);
      default:
        expr(e, I32).concat([I32Eqz]);
    };
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e.expr {
      case TWhile(econd, e, normalWhile):
        [Block(
          Empty, 
          [Loop(
            Empty, 
            if (normalWhile)
              exprInverted(econd).concat([BrIf(1)]).concat(expr(e, null)).concat([Br(0)])
            else
              expr(e, null).concat(expr(econd, I32)).concat([If(Empty, [Br(0)], [Br(1)])])
          )]
        )];
      default: null;
    }
  }
}