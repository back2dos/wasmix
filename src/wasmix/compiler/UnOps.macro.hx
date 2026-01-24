package wasmix.compiler;

function unOp(m:MethodScope, op:Unop, postFix, v:TypedExpr, pos, expected) {
  return switch op {
    case OpIncrement | OpDecrement:
      switch v.expr {
        case TLocal(v):
          final id = m.varId(v),
                op = op == OpIncrement ? I32Add : I32Sub;

          final coerce = m.coerce(m.type(v.t, pos), expected, pos);
          if (postFix) {
            final ret = [LocalGet(id), I32Const(1), op, LocalSet(id)];
            switch coerce {
              case [Drop]: ret;
              case e: [LocalGet(id)].concat(e).concat(ret);
            }
          }
          else switch coerce {
            case [Drop]: [LocalGet(id), I32Const(1), op, LocalSet(id)];
            case e: [LocalGet(id), I32Const(1), op, LocalTee(id)].concat(e);
          }
        default:
          Context.error('Operand must be a local variable', v.pos);
      }
    case OpNot:
      m.expr(v, I32).concat([I32Eqz]);
    case OpNeg:
      m.expr(v, I32).concat([I32Const(0), I32Sub]);
    case OpNegBits:
      m.expr(v, I32).concat([I32Const(-1), I32Xor]);
    case OpSpread:
      Context.error('Spread operator not supported', pos);
  }
}