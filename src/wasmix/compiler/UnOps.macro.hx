package wasmix.compiler;

function unOp(m:MethodScope, op:Unop, postFix, v:TypedExpr, pos) {
  return switch op {
    case OpIncrement | OpDecrement:
      switch v.expr {
        case TLocal(v):
          final id = m.varId(v),
                op = op == OpIncrement ? I32Add : I32Sub;

          if (postFix) 
            [LocalGet(id), LocalGet(id), I32Const(1), op, LocalSet(id)];
          else 
            [LocalGet(id), I32Const(1), op, LocalTee(id)];
        default:
          Context.error('Operand must be a local variable', v.pos);
      }
    case OpNot:
      m.expr(v).concat([I32Eqz]);
    case OpNeg:
      m.expr(v).concat([I32Const(0), I32Sub]);
    case OpNegBits:
      m.expr(v).concat([I32Const(-1), I32Xor]);
    case OpSpread:
      Context.error('Spread operator not supported', pos);
  }
}