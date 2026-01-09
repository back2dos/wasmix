package wasmix;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.*;
import wasmix.wasm.Data;

using haxe.macro.Tools;

class Transpiler {
  static function error(pos:Position, error:String):Dynamic {
    return Context.error(error, pos);
  }

  static public function transpileFunction(f:TFunc) {

  }

  static public function transpileReturnType(pos:Position, t:Type):Array<ValueType> {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(_.toString() => 'Void', _): [];
      case t: [transpileType(pos, t)];
    }
  }

  static public function transpileType(pos:Position, t:Type):ValueType {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(a, _):
        switch a.toString() {
          case "Bool" | "Int": I32;
          case "Float": F64;
          case unsupported: error(pos, 'Unsupported type $unsupported');
        }
      default: error(pos, 'Unsupported type ${t.toString()}');
    }
  }
  
  static public function transpile(e:TypedExpr):Expression {
    return switch(e.expr) {
      case TConst(c):
        transpileConstant(c);
        
      case TLocal(v):
        [Instruction.LocalGet(v.id)];
        
      case TBinop(op, e1, e2):
        var expr1 = transpile(e1);
        var expr2 = transpile(e2);
        expr1.concat(expr2).concat([transpileBinop(op, e1.t, e2.t)]);
        
      case TUnop(op, postFix, e1):
        var expr1 = transpile(e1);
        expr1.concat([transpileUnop(op, postFix, e1.t)]);
        
      case TBlock(el):
        var result:Expression = [];
        for(elem in el) {
          result = result.concat(transpile(elem));
        }
        result;
        
      case TIf(econd, eif, eelse):
        var cond = transpile(econd);
        var thenBody = transpile(eif);
        var elseBody = eelse != null ? transpile(eelse) : null;
        var blockType = getBlockType(eif.t);
        cond.concat([Instruction.If(blockType, thenBody, elseBody)]);
        
      case TReturn(e):
        if(e == null) {
          [Instruction.Return];
        } else {
          transpile(e).concat([Instruction.Return]);
        }
        
      case TVar(v, expr):
        if(expr == null) {
          error(e.pos, "Variable declaration without initialization not supported");
        }
        transpile(expr).concat([Instruction.LocalSet(v.id)]);
        
      case TParenthesis(e1):
        transpile(e1);
        
      case TBreak:
        error(e.pos, "Break not yet supported");
        
      case TContinue:
        error(e.pos, "Continue not yet supported");
        
      case TThrow(e1):
        error(e.pos, "Throw not yet supported");
        
      case TTry(e1, catches):
        error(e.pos, "Try-catch not yet supported");
        
      case TSwitch(e1, cases, edef):
        error(e.pos, "Switch not yet supported");
        
      case TWhile(econd, e1, normalWhile):
        error(e.pos, "While loops not yet supported");
        
      case TFor(v, e1, e2):
        error(e.pos, "For loops not yet supported");
        
      case TCall(e1, el):
        error(e.pos, "Function calls not yet supported");
        
      case TNew(c, params, el):
        error(e.pos, "Constructor calls not yet supported");
        
      case TField(e1, fa):
        error(e.pos, "Field access not yet supported");
        
      case TArray(e1, e2):
        error(e.pos, "Array access not yet supported");
        
      case TArrayDecl(el):
        error(e.pos, "Array declaration not yet supported");
        
      case TObjectDecl(fields):
        error(e.pos, "Object declaration not yet supported");
        
      case TTypeExpr(m):
        error(e.pos, "Type expression not yet supported");
        
      case TFunction(tfunc):
        error(e.pos, "Local functions not yet supported");
        
      case TCast(e1, m):
        error(e.pos, "Cast not yet supported");
        
      case TMeta(m, e1):
        transpile(e1); // Ignore metadata
        
      case TEnumParameter(e1, ef, index):
        error(e.pos, "Enum parameter access not yet supported");
        
      case TEnumIndex(e1):
        error(e.pos, "Enum index access not yet supported");
        
      case TIdent(s):
        error(e.pos, "Unknown identifier: " + s);
    }
  }
  
  static function transpileConstant(c:TConstant):Expression {
    return switch(c) {
      case TInt(i):
        [Instruction.I32Const(i)];
        
      case TFloat(s):
        var f = Std.parseFloat(s);
        [Instruction.F64Const(f)];
        
      case TBool(b):
        [Instruction.I32Const(b ? 1 : 0)];
        
      case TString(s):
        error(null, "String constants not yet supported");
        
      case TNull:
        error(null, "Null constant not yet supported");
        
      case TThis:
        error(null, "This not yet supported");
        
      case TSuper:
        error(null, "Super not yet supported");
    }
  }
  
  static function transpileBinop(op:Binop, t1:Type, t2:Type):Instruction {
    var isFloat = isFloatType(t1) || isFloatType(t2);
    
    return switch(op) {
      case OpAdd:
        if(isFloat) F64Add else I32Add;
      case OpMult:
        if(isFloat) F64Mul else I32Mul;
      case OpDiv:
        if(isFloat) F64Div else I32DivS;
      case OpSub:
        if(isFloat) F64Sub else I32Sub;
      case OpMod:
        if(isFloat) error(null, "Modulo not supported for floats") else I32RemS;
      case OpEq:
        if(isFloat) F64Eq else I32Eq;
      case OpNotEq:
        if(isFloat) F64Ne else I32Ne;
      case OpLt:
        if(isFloat) F64Lt else I32LtS;
      case OpLte:
        if(isFloat) F64Le else I32LeS;
      case OpGt:
        if(isFloat) F64Gt else I32GtS;
      case OpGte:
        if(isFloat) F64Ge else I32GeS;
      case OpAnd:
        I32And;
      case OpOr:
        I32Or;
      case OpShl:
        I32Shl;
      case OpShr:
        I32ShrS;
      case OpUShr:
        I32ShrU;
      default:
        error(null, "Binary operator not yet supported: " + op);
    }
  }
  
  static function transpileUnop(op:Unop, postFix:Bool, t:Type):Instruction {
    var isFloat = isFloatType(t);
    
    return switch(op) {
      case OpIncrement:
        if(isFloat) {
          error(null, "Increment not supported for floats");
        } else {
          // For postfix: value stays, for prefix: increment first
          // This is simplified - in reality we'd need to handle the value on stack
          I32Add; // This would need the constant 1 pushed first
        }
      case OpDecrement:
        if(isFloat) {
          error(null, "Decrement not supported for floats");
        } else {
          I32Sub; // This would need the constant 1 pushed first
        }
      case OpNot:
        I32Eqz; // Logical not: convert to 0/1, then eqz
      case OpNeg:
        if(isFloat) F64Neg else error(null, "Negation for ints not yet supported");
      case OpNegBits:
        I32Xor; // Would need -1 (all bits set) to XOR with
      case OpSpread:
        error(null, "Spread operator not yet supported");
    }
  }
  
  static function getBlockType(t:Type):BlockType {
    if(isIntType(t)) {
      return ValueType(I32);
    } else if(isFloatType(t)) {
      return ValueType(F64);
    } else {
      return Empty;
    }
  }
  
  static function isIntType(t:Type):Bool {
    return switch(t) {
      case TAbstract(a, _):
        var name = a.get().name;
        name == "Int";
      default:
        false;
    }
  }
  
  static function isFloatType(t:Type):Bool {
    return switch(t) {
      case TAbstract(a, _):
        var name = a.get().name;
        name == "Float";
      default:
        false;
    }
  }
}
#end