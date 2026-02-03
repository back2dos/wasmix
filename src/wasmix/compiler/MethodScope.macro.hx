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

  static function isString(e:TypedExpr) {
    return Context.followWithAbstracts(e.t).match(TInst(_.toString() => 'String', _));
  }
  
  function scan(e:TypedExpr) {
    if (e != null) switch e.expr {
      case TVar(v, init): 
        
        varIds[v.id] = varIdCounter++;
        locals.push(type(v.t, e.pos));
        scan(init);

      case TArray(arr, index):

        scan(arr);
        scan(index);

        cls.imports.addStaticByName('wasmix.runtime.Arrays', 'get', FunctionType.arrayGet(arr.t, e.t));

      case TArrayDecl(values):
        for (v in values) scan(v);

        cls.imports.addStaticByName('wasmix.runtime.Arrays', 'literal', FunctionType.arrayLiteral(e.t, values.length));

      case TField(_, FEnum(_.get() => enm, ef)):

        cls.imports.add(Static(enm, ef.name, Get(e.t)), e.pos);

      case TField(_, FStatic(_.get() => c, _.get() => f)):

        cls.imports.add(Static(c, f.name, Get(e.t)), e.pos);

      case TNew(_.get() => cl, _, args):
        for (a in args) scan(a);
          
        cls.imports.add(Constructor(cl, FunctionType.of(cl.constructor.get().type, e.pos, args.length, e.t)), e.pos);
  
      case TBinop(op, e1, e2) if (isString(e1) || isString(e2)):

        scan(e1);
        scan(e2);

        function make(op:Binop) {
          final method = op.getName().toLowerCase().substr(2);
          final ret = Context.typeExpr(macro @:pos(e.pos) wasmix.runtime.Strings.$method(${Context.storeTypedExpr(e1)}, ${Context.storeTypedExpr(e2)}));
          scan(ret);
          return ret;
        }

        switch op {
          case OpAssign:
          case OpAssignOp(op):
            e.expr = TBinop(OpAssign, e1, make(op));
          default:
            e.expr = make(op).expr;
        }

      case TBinop(op = OpBoolAnd | OpBoolOr, e1, e2):

        scan(e1);
        scan(e2);

        e.expr = TIf(
          e1,
          if (op == OpBoolAnd) e2 else Context.typeExpr(macro true),
          if (op == OpBoolAnd) Context.typeExpr(macro false) else e2
        );

      case TField(owner, FInstance(_, _, _.get().name => name)) if (BufferView.getType(owner.t) == None):

        scan(owner);

        cls.imports.add(Field(owner.t, name, Get(e.t)), e.pos);

      case TCall({ expr: TField(_, FEnum(_.get() => enm, f)), t: sig }, args):

        for (a in args) scan(a);

        cls.imports.add(Static(enm, f.name, Method(FunctionType.of(sig, e.pos, args.length))), e.pos);

      case TCall({ expr: TField(_, FStatic(_.get() => c, _.get() => f)), t: sig }, args):

        for (a in args) scan(a);

        if (!cls.isSelf(c))
          cls.imports.add(Static(c, f.name, Method(FunctionType.of(sig, e.pos, args.length))), e.pos);
      
      case TCall({ expr: TField(receiver, FInstance(_, _, _.get().name => name)), t: sig }, args):

        scan(receiver);

        for (a in args) scan(a);

        cls.imports.add(Field(receiver.t, name, Method(FunctionType.of(sig, e.pos, args.length))), e.pos);

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
      case TConst(TString(s)):
        cls.imports.addString(s);
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
      case [TNull, null]: [];
      case [TNull, ExternRef]: [RefNull(ExternRef)];
      case [TNull, v]: error('Cannot coerce null to ${v}', pos);
      case [TInt(i), I32 | null]: [I32Const(i)];
      case [TInt(i), F32]: [F32Const(i)];
      case [TInt(i), F64]: [F64Const(i)];
      case [TFloat(f), F32]: [F32Const(Std.parseFloat(f))];
      case [TFloat(f), F64 | null]: [F64Const(Std.parseFloat(f))];
      case [TBool(b), I32 | null]: [I32Const(b ? 1 : 0)];
      case [TInt(_) | TFloat(_) | TBool(_), expected]: error('Cannot coerce ${t} to ${expected}', pos);
      case [TString(s), ExternRef]: [GlobalGet(cls.imports.findString(s))];
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
      case BufferView.access(this, e) => Some(v): v.get(expected);
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

      case TNew(_.get() => cl, _, args):

        [Call(cls.imports.find(Constructor(cl, FunctionType.of(cl.constructor.get().type, e.pos, args.length, e.t)), e.pos))];

      case TReturn(e):
        
        expr(e, returnType).concat([Return]);
        
      case TField(target, FInstance(BufferView.getType(_) => Some(type), _, _.get().name => name )):

        BufferView.getField(this, target, name, type, expected, e.pos);

      case TField(owner, fa):

        function call(id:Int)
          return [Call(id)].concat(coerce(cls.retType(e.t, e.pos), expected, e.pos));
  
        switch fa {
          case FStatic(_.get() => c, _.get() => f): 
            call(cls.imports.find(Static(c, f.name, Get(e.t)), e.pos));
          case FEnum(_.get() => enm, ef): 
            call(cls.imports.find(Static(enm, ef.name, Get(e.t)), e.pos));
          case FInstance(_, _, _.get().name => name): 
            expr(owner, ExternRef).concat(call(cls.imports.find(Field(owner.t, name, Get(e.t)), e.pos)));
          default:
            error('${fa.getName().substr(1)} field access not supported ($fa)', e.pos);  
        }
  
      case TCall(e = { t: sig }, args):

        final f = FunctionType.of(sig, e.pos, args.length);

        function call(id:Int) {
          return 
            [for (i => a in args) for (i in expr(a, type(f.args[i].type, a.pos))) i]
              .concat([Call(id)])
              .concat(coerce(cls.retType(f.ret, e.pos), expected, e.pos));
        }
        switch e.expr {
          case TField(_, FStatic(_.get() => c, _.get() => cf)):
            call(
              if (cls.isSelf(c)) cls.getFunctionId(cf.name)
              else cls.imports.find(Static(c, cf.name, Method(f)), e.pos)
            );
          case TField(_, FEnum(_.get() => enm, ef)):
            call(cls.imports.find(Static(enm, ef.name, Method(f)), e.pos));
          case TField(receiver, FInstance(_, _, _.get().name => name)):
            expr(receiver, type(receiver.t, e.pos)).concat(
              call(cls.imports.find(Field(receiver.t, name, Method(f)), e.pos))
            );
          default:
            error('Invalid call target $e', e.pos);
        }
      case TContinue: [Br(0)];
      case TBreak: [Br(1)];
      case TUnop(op, postFix, v):
        unOp(this, op, postFix, v, e.pos, expected);
      case TBinop(op, e1, e2):
        binOp(this, op, e1, e2, e.pos, expected);
      case TArray(arr, index):

        expr(arr, ExternRef)
          .concat(expr(index, I32))
          .concat([Call(cls.imports.findStaticByName('wasmix.runtime.Arrays', 'get', FunctionType.arrayGet(arr.t, e.t)))])
          .concat(coerce(cls.retType(e.t, e.pos), expected, e.pos));

      case TArrayDecl(values):
        final expected = switch e.t {
          case TInst(_.get() => { pack: [], name: 'Array' }, [t]): cls.type(t, e.pos);
          default: throw 'assert';
        }

        [for (v in values) for (i in expr(v, expected)) i]
          .concat([Call(cls.imports.findStaticByName('wasmix.runtime.Arrays', 'literal', FunctionType.arrayLiteral(e.t, values.length)))]);
      default: 
        error('Unsupported expression ${e.expr.getName()} in ${fn.expr.toString(true)}', e.pos);
    }
  }

  var returnType:Null<ValueType>;

  static final BOOL = Context.getType('Bool');
  static final INT = Context.getType('Int');

  public inline function type(t, pos)
    return cls.type(t, pos);

  function transpile() {    
    
    return {
      typeIndex: cls.signature([for (a in fn.args) a.v.t], fn.t, field.pos),
      locals: locals,
      body: expr(fn.expr, null),
    }
  }
}