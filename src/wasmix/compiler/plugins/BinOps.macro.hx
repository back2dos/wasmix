package wasmix.compiler.plugins;

import wasmix.runtime.BufferViewType;

class BinOps extends Plugin {
  static public function assignment(e:TypedExpr) {
    return switch e.expr {
      case TBinop(op = OpAssign | OpAssignOp(_), e1, e2):
        Some({
          lhs: e1,
          rhs: e2,
          op: switch op {
            case OpAssignOp(op): Some(op);
            default: None; 
          },
        });
      default: None;
    }
  }
  public function make(op:Binop, e1:TypedExpr, e2:TypedExpr, expected:ValueType, pos:Position) {
    return switch [op, e1, e2] {
      case [OpEq, { expr: TConst(TInt(0)) }, i] | [OpEq, i, { expr: TConst(TInt(0)) }]:
        
        expr(i, I32).concat([I32Eqz]);

      default:
        
        final t1 = BinOpType.ofExpr(e1);
        final t2 = BinOpType.ofExpr(e2);
        final opType = t1.with(t2, expected);
        
        final valueType = opType.toValueType();
        
        expr(e1, valueType)
          .concat(expr(e2, valueType))
          .concat([opType.getInstruction(op, pos)]);
    }
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e.expr {
      case TBinop(OpAssign | OpAssignOp(_), e, _):
        error('Invalid LHS for assignment', e.pos);
      case TBinop(op, e1, e2):
        make(op, e1, e2, expected, e.pos);
      default: null;
    }
  }

}

enum abstract BinOpType(String) {
  var BinI32;
  var BinI64;
  var BinF32;
  var BinF64;

  public function toValueType():ValueType
    return switch abstract {
      case BinI32: I32;
      case BinI64: I64;
      case BinF32: F32;
      case BinF64: F64;
    }

  public function with(that:BinOpType, expected:Null<ValueType>)
    return switch [abstract, that, expected] {
      case [_, _, F32]: BinF32;
      case [_, _, F64]: BinF64;
      case [BinF32, BinF64, I32] | [BinF64, BinF32, I32]: BinF32;
      case [BinF64, _, _] | [_, BinF64, _]: BinF64;
      case [BinF32, BinI64, _] | [BinI64, BinF32, _]: BinF64;
      case [BinF32, _, _] | [_, BinF32, _]: BinF32;
      case [BinI64, _, _] | [_, BinI64, _]: BinI64;
      case [BinI32, _, _] | [_, BinI32, _]: BinI32;
    }

  static public function ofType(t:Type, ?pos:Position) {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(a, _):
        switch a.toString() {
          case "Int" | "Bool": BinI32;
          case "wasmix.runtime.Float32": BinF32;
          case "Float": BinF64;
          default: error('Unsupported type ${a.toString()}', pos);
        }
      default: error('Unsupported type ${t.toString()}', pos);
    }
  }

  static public function ofExpr(e:TypedExpr)
    return ofType(e.t, e.pos);

  static public function forBuffer(b:BufferViewType):BinOpType
    return switch b {
      case Float32: BinF32;
      case Float64: BinF64;
      default: BinI32;
    }

  public function getInstruction(op:Binop, ?pos:Position):Instruction {
    return switch abstract {
      case BinI32:
        switch op {
          case OpAdd: I32Add;
          case OpSub: I32Sub;
          case OpMult: I32Mul;
          case OpDiv: I32DivS;
          case OpMod: I32RemS;
          case OpEq: I32Eq;
          case OpNotEq: I32Ne;
          case OpLt: I32LtS;
          case OpLte: I32LeS;
          case OpGt: I32GtS;
          case OpGte: I32GeS;
          case OpAnd: I32And;
          case OpOr: I32Or;
          case OpShl: I32Shl;
          case OpShr: I32ShrS;
          case OpUShr: I32ShrU;
          case OpXor: I32Xor;
          default: error('Unsupported binary operator ${op.getName()}', pos);
        }
      case BinI64:
        switch op {
          case OpAdd: I64Add;
          case OpSub: I64Sub;
          case OpMult: I64Mul;
          case OpDiv: I64DivS;
          case OpMod: I64RemS;
          case OpEq: I64Eq;
          case OpNotEq: I64Ne;
          case OpLt: I64LtS;
          case OpLte: I64LeS;
          case OpGt: I64GtS;
          case OpGte: I64GeS;
          case OpAnd: I64And;
          case OpOr: I64Or;
          case OpShl: I64Shl;
          case OpShr: I64ShrS;
          case OpUShr: I64ShrU;
          case OpXor: I64Xor;
          default: error('Unsupported binary operator ${op.getName()}', pos);
        }
      case BinF32: 
        switch op {
          case OpAdd: F32Add;
          case OpSub: F32Sub;
          case OpMult: F32Mul;
          case OpDiv: F32Div;
          case OpEq: F32Eq;
          case OpNotEq: F32Ne;
          case OpLt: F32Lt;
          case OpLte: F32Le;
          case OpGt: F32Gt;
          case OpGte: F32Ge;
          default: error('Unsupported binary operator ${op.getName()} for F32', pos);
        }
      case BinF64: 
        switch op {
          case OpAdd: F64Add;
          case OpSub: F64Sub;
          case OpMult: F64Mul;
          case OpDiv: F64Div;
          case OpEq: F64Eq;
          case OpNotEq: F64Ne;
          case OpLt: F64Lt;
          case OpLte: F64Le;
          case OpGt: F64Gt;
          case OpGte: F64Ge;
          default: error('Unsupported binary operator ${op.getName()} for F64', pos);
        }
    }
  }
}