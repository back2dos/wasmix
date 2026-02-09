package wasmix.compiler.plugins;

class UnOps extends Plugin {
  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e.expr {
      case TUnop(op, postFix, v):
        switch op {
          case OpIncrement | OpDecrement:
            error('Invalid target for $op', e.pos);
          case OpNot:
            m.expr(v, I32).concat([I32Eqz]);
          case OpNeg:
            m.expr(v, I32).concat([I32Const(0), I32Sub]);
          case OpNegBits:
            m.expr(v, I32).concat([I32Const(-1), I32Xor]);
          case OpSpread:
            error('Spread operator not supported', e.pos);
        }
      default: null;
    }
  }
}