package wasmix.compiler;

import wasmix.compiler.BinOps;
import wasmix.compiler.UnOps;

class MethodScope {
  public final field:ClassField;
  public final fn:TFunc;

  final cls:ClassScope;
  
  var varIdCounter = 0;

  final varIds = new Map<Int, Int>();
  final locals = new Array<ValueType>();
  final tmpIds = new Map<ValueType, Int>();
  
  final basePtrIds = new Map<Int, Int>();
  final lengthIds = new Map<Int, Int>();

  function tmp(t:ValueType) {
    return tmpIds[t] ??= {
      final id = varIdCounter++;
      locals.push(t);
      id;
    }
  }

  public function dup(t:ValueType) {
    final id = tmp(t);
    return [LocalTee(id), LocalGet(id)];
  }

  public inline function varId(v:TVar) {
    return varIds[v.id];
  }

  public function new(cls, field, fn) {
    this.cls = cls;
    this.field = field;
    this.fn = fn;
    
    if (field.name == 'memory') 
      error('Name "memory" is reserved', field.pos);
    
    for (a in fn.args) varIds[a.v.id] = varIdCounter++;
    
    // LICM: For BufferView parameters, pre-allocate locals for cached base pointers and lengths
    for (a in fn.args) {
      switch BufferView.getType(a.v.t) {
        case Some(_):
          basePtrIds[a.v.id] = varIdCounter++;
          locals.push(I32);
          lengthIds[a.v.id] = varIdCounter++;
          locals.push(I32);
        case None:
      }
    }
  }
  
  public inline function getCachedBasePtr(varId:Int):Null<Int> {
    return basePtrIds[varId];
  }
  
  public inline function getCachedLength(varId:Int):Null<Int> {
    return lengthIds[varId];
  }

  var scanned = false;
  
  public function prepare() {
    if (!scanned) {
      scan(fn.expr);

      switch Context.followWithAbstracts(fn.t) {
        case _.toString() => 'Void':
        case t: returnType = type(t, field.pos);
      }
      scanned = true;
    }

    return transpile;
  }
  
  function scan(e:TypedExpr) {
    if (e != null) switch e.expr {
      case TVar(v, init): 
        
        varIds[v.id] = varIdCounter++;
        locals.push(type(v.t, e.pos));
        scan(init);

      case TField(_, FEnum(_.get() => enm, ef)):

        cls.imports.addStatic(enm, ef, e.t, e.pos);

      case TField(_, FStatic(_.get() => c, _.get() => f)) :

        cls.imports.addStatic(c, f, e.t, e.pos);

      case TField(_, v):
        error('${v.getName().substr(1)} field access not supported', e.pos);

      case TCall({ expr: TField(_, FStatic(_.get() => c, _.get() => f)), t: sig }, args):

        for (a in args) scan(a);

        if (!cls.isSelf(c))
          cls.imports.addStatic(c, f, sig, e.pos);

      case TSwitch(target, cases, eDefault):

        final tmp = '_wasmix_tmp_${varIdCounter}';// TODO: only temp var if switch target is not a var

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

        scan(e);
      case TEnumIndex(e):
        scan(e);
        cls.imports.addStaticByName('wasmix.runtime.Enums', 'index', INDEX);
      case TEnumParameter(target, _):
        scan(target);
        cls.imports.addStaticByName('wasmix.runtime.Enums', 'param', enumParam(e.t));
      default:

        e.iter(scan);
    }
  }

  function enumParam(t:Type) {
    return PARAM.type.applyTypeParameters(PARAM.params, [t]);
  }

  static final PARAM = Imports.resolveStaticField('wasmix.runtime.Enums', 'param');
  static final INDEX = Context.typeof(macro wasmix.runtime.Enums.index);

  static function error(message:String, pos:Position):Dynamic {
    return Context.error(message, pos);
  }

  function const(pos:Position, t:TConstant, expected:Null<ValueType>):Expression
    return switch [t, expected] {
      case [TInt(i), I32 | null]: [I32Const(i)];
      case [TInt(i), F32]: [F32Const(i)];
      case [TInt(i), F64]: [F64Const(i)];
      case [TFloat(f), F32]: [F32Const(Std.parseFloat(f))];
      case [TFloat(f), F64 | null]: [F64Const(Std.parseFloat(f))];
      case [TBool(b), I32 | null]: [I32Const(b ? 1 : 0)];
      case [TInt(_) | TFloat(_) | TBool(_), expected]: error('Cannot coerce ${t} to ${expected}', pos);
      default: error('Unsupported constant type', pos);
    }

  function strip(e:TypedExpr):TypedExpr 
    return if (e == null) null else switch e.expr {
      case TParenthesis(e), TMeta(_, e), TCast(e, _), TBlock([e]): strip(e);
      default: e;
    }

  // Generate inverted condition (returns true when original would be false)
  // This avoids needing I32Eqz after comparisons
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
          binOp(this, inverted, e1, e2, e.pos, I32);
        else
          expr(e, I32).concat([I32Eqz]);
      case TUnop(OpNot, false, inner):
        expr(inner, I32);
      default:
        expr(e, I32).concat([I32Eqz]);
    };
  }

  public function coerce(from:Null<ValueType>, to:Null<ValueType>, pos:Position):Expression {
    return switch [from, to] {
      case [null, null]: [];
      case [null, v]: error('Cannot coerce Void to ${to}', pos);
      case [_, null]: [Drop];
      case [F32, F64]: [F64PromoteF32];
      case [F64, F32]: [F32DemoteF64];
      case [I32, F32]: [F32ConvertI32S];
      case [I32, F64]: [F64ConvertI32S];
      case [a, b] if (a.equals(b)): [];
      default: error('Cannot coerce ${from} to ${to}', pos);
    }
  }

  public function expr(e:TypedExpr, expected:Null<ValueType>):Expression {
    return if (e == null) [] else switch e.expr {// strip here?
      case TConst(c): const(e.pos, c, expected);
      case TLocal(v): 
        switch expected {
          case null: [];
          default: [LocalGet(varId(v))].concat(coerce(type(v.t, e.pos), expected, e.pos));
        }
      case TVar(v, e): 
        if (e == null) [];
        else {
          final ret = expr(e, type(v.t, e.pos));
          ret.push(LocalSet(varId(v)));
          ret;
        }
      case TParenthesis(e), TMeta(_, e), TCast(e, null): expr(e, expected);
      case TEnumIndex(e):
        expr(e, ExternRef).concat([Call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'index', INDEX))]);
      case TEnumParameter(target, _, index):
        expr(target, ExternRef).concat([I32Const(index), Call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'param', enumParam(e.t)))]);
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
      case TBlock(el):
        final last = el.length - 1;
        [for (pos => e in el) for (i in expr(e, if (pos == last) expected else null)) i];
      case TIf(econd, eif, eelse):
        
        final cond = expr(econd, I32),
              thenBody = expr(eif, expected),
              elseBody = expr(eelse, expected);

        final blockType = if (expected == null) Empty else BlockType.Value(expected);
        cond.concat([If(blockType, thenBody, elseBody)]);

      case TReturn(e):
        expr(e, returnType).concat([Return]);
      case TField(_, FEnum(_.get() => enm, ef)):
        [Call(cls.imports.findStatic(enm, ef, e.t))];
      case TField(_, FStatic(_.get() => c, _.get() => f)):
        [Call(cls.imports.findStatic(c, f, e.t))];
      case TField(target, FInstance(BufferView.getType(_) => Some(type), _, _.get() => { name: 'length' })):
        // LICM: Use cached length if available
        switch strip(target).expr {
          case TLocal(v):
            switch getCachedLength(v.id) {
              case null: expr(target, I64).concat([I64Const(32), I64ShrU, I32WrapI64]);
              case lengthLocalId: [LocalGet(lengthLocalId)];
            }
          default:
            expr(target, I64).concat([I64Const(32), I64ShrU, I32WrapI64]);
        }
      case TField(_):
        error('Invalid field access', e.pos);
      case TCall(e = { t: sig }, args):

        function call(id:Int) {
          return switch Context.follow(sig) {
            case TFun(argTypes, retType):
              [for (i => a in args) for (i in expr(a, type(argTypes[i].t, a.pos))) i]
                .concat([Call(id)])
                .concat(coerce(type(retType, e.pos), expected, e.pos));
            default:
              throw 'assert';
          }
        }
        switch e.expr {
          case TField(_, FStatic(_.get() => c, _.get() => cf)):
            call(
              if (cls.isSelf(c)) cls.getFunctionId(cf.name)
              else cls.imports.findStatic(c, cf, sig)
            );
          case TField(_, FEnum(_.get() => enm, ef)):
            call(cls.imports.findStatic(enm, ef, e.t));
          default:
            error('Invalid call target $e', e.pos);
        }
      case TContinue: [Br(0)];
      case TBreak: [Br(1)];
      case TUnop(op, postFix, v):
        unOp(this, op, postFix, v, e.pos, expected);
      case TBinop(op, e1, e2):
        binOp(this, op, e1, e2, e.pos, expected);
      default: 
        switch BufferView.access(this, e) {
          case Some(v):
            v.get(expected);
          default:
            error('Unsupported expression ${e.expr.getName()} in ${fn.expr.toString(true)}', e.pos);
        }
    }
  }

  var returnType:Null<ValueType>;

  static final BOOL = Context.getType('Bool');
  static final INT = Context.getType('Int');

  public inline function type(t, pos)
    return cls.type(t, pos);

  function transpile() {    
    // LICM: Emit base pointer and length extraction at function start
    final preamble:Expression = [];
    for (a in fn.args) {
      switch basePtrIds[a.v.id] {
        case null:
        case basePtrLocalId:
          // Extract base pointer: local.get param; i32.wrap_i64; local.set basePtr
          preamble.push(LocalGet(varIds[a.v.id]));
          preamble.push(I32WrapI64);
          preamble.push(LocalSet(basePtrLocalId));
      }
      switch lengthIds[a.v.id] {
        case null:
        case lengthLocalId:
          // Extract length: local.get param; i64.const 32; i64.shr_u; i32.wrap_i64; local.set length
          preamble.push(LocalGet(varIds[a.v.id]));
          preamble.push(I64Const(32));
          preamble.push(I64ShrU);
          preamble.push(I32WrapI64);
          preamble.push(LocalSet(lengthLocalId));
      }
    }
    
    return {
      typeIndex: cls.signature([for (a in fn.args) a.v.t], fn.t, field.pos),
      locals: locals,
      body: preamble.concat(expr(fn.expr, null)),
    }
  }
}