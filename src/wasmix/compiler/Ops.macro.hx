package wasmix.compiler;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import wasmix.wasm.Data;

using haxe.macro.Tools;

function binOp(op:Binop, e1:TypedExpr, e2:TypedExpr):Instruction {
  return switch opType(e1).with(opType(e2)) {
    case I32:
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
        default: Context.error('Unsupported binary operator ${op.getName()}', e1.pos);
      }
    case I64:
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
        default: Context.error('Unsupported binary operator ${op.getName()}', e1.pos);
      }
    case F32: 
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
        default: Context.error('Unsupported binary operator ${op.getName()} for F32', e1.pos);
      }
    case F64: 
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
        default: Context.error('Unsupported binary operator ${op.getName()} for F64', e1.pos);
      }
    case STRING:
      Context.error('String concatenation not supported', e1.pos);
  }
}

private function opType(e:TypedExpr) {
  return switch Context.followWithAbstracts(e.t) {
    case TAbstract(a, _):
      switch a.toString() {
        case "Int" | "Bool": I32;
        case "Float": F64;
        case "String": STRING;
        default: Context.error('Unsupported type ${a.toString()}', e.pos);
      }
    default: Context.error('Unsupported type ${e.t.toString()}', e.pos);
  }
}

private enum abstract OpType(String) {
  var I32;
  var I64;
  var F32;
  var F64;
  var STRING;

  public function with(that:OpType)
    return switch [abstract, that] {
      case [STRING, _] | [_, STRING]: STRING;
      case [F64, _] | [_, F64]: F64;
      case [F32, I64] | [I64, F32]: F64;
      case [F32, _] | [_, F32]: F32;
      case [I64, _] | [_, I64]: I64;
      case [I32, _] | [_, I32]: I32;
    }
}