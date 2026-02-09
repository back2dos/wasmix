package wasmix.compiler.plugins;

private enum Result {
  Found(m:Imports.MemberImport, exprs:Array<TypedExpr>);
  NotFound;
}

class Classes extends Plugin {
  function ownId(m:Imports.MemberImport) {
    return switch m {
      case Static(c, name, Method(_)): 
        if (ClassScope.typeId(c) == cls.name) cls.getFunctionId(name);
        else null;
      default: null;
    }
  }

  function fieldAccess(e:TypedExpr) {
    return switch e.expr {
      case asFieldUpdate(e) => Some(e): e;
      case TField(owner, FInstance(_, _, _.get().name => name)):
      
        Found(Field(owner.t, name, Get(e.t)), [owner]);

      case TField(owner, FStatic(_.get() => c, _.get() => f)):
        
        Found(Static(c, f.name, Get(e.t)), []);

      case TCall(e = { expr: TField(owner, FInstance(_, _, _.get().name => name)) }, args):
      
        Found(Field(owner.t, name, Method(FunctionType.of(e.t, args.length))), [owner].concat(args));

      case TCall(e = { expr: TField(owner, FStatic(_.get() => c, _.get() => f)) }, args):
        
        Found(Static(c, f.name, Method(FunctionType.of(e.t, args.length))), args);

      default:

        return NotFound;
    }
  }

  function asFieldUpdate(e:TypedExpr) {
    return asUpdateOf(e, (e, kind) -> switch fieldAccess(e) {
      case Found(Field(receiver, name, Get(t)), exprs):

        Some(Found(Field(receiver, name, Update(t, kind.exprToType())), exprs.concat([kind.value()])));

      case Found(Static(c, name, Get(t)), exprs):

        Some(Found(Static(c, name, Update(t, kind.exprToType())), exprs.concat([kind.value()])));

      default: None;
    });
  }

  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e {        
      case fieldAccess(_) => Found(a, exprs):
        for (e in exprs) rec(e);

        if (ownId(a) == null) cls.imports.add(a, e.pos);
        else true;

      default: false;
    }
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e {
      case fieldAccess(_) => Found(a, exprs):

        final expectedArgs = switch a {
          case Static([] => prelude, _, kind)
             | Field([toValueType(_)] => prelude, _, kind): 

            prelude.concat(switch kind {
              case Method(t):
                [for (i => a in t.args) a.valueType];
              case Get(t):  
                [];
              case Update(ret, kind):
                [toValueType(kind.value(v -> Context.getType('Int')))];
            });
            
          case Constructor(c, t): throw 'todo';
        }

        [for (pos => e in exprs) for (i in expr(e, expectedArgs[pos])) i]
          .concat([Call(ownId(a) ?? cls.imports.find(a, e.pos))])
          .concat(coerce(cls.retType(e.t, e.pos), expected, e.pos));

      default: null;
    }
  }
}