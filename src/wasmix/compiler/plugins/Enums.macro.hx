package wasmix.compiler.plugins;

class Enums extends Plugin {
  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case TEnumIndex(e):
        
        rec(e);
        cls.imports.addStaticByName(RUNTIME, 'index', INDEX);
        true;

      case TEnumParameter(target, _):
        
        rec(target);
        cls.imports.addStaticByName(RUNTIME, 'param', enumParam(e.t));

      case TField(_, FEnum(_.get() => enm, ef)):

        cls.imports.add(Static(enm, ef.name, Get(e.t)), e.pos);

      case TCall(e = { expr: TField(_, FEnum(_.get() => enm, ef)) }, args):
        
        for (a in args) rec(a);

        cls.imports.add(Static(enm, ef.name, Method(FunctionType.of(e.t, args.length))), e.pos);

      default: false;
    }
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    function call(id) return this.call(id, e, expected);

    return switch e.expr {
      case TEnumIndex(e):

        expr(e, ExternRef).concat(call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'index', INDEX)));

      case TEnumParameter(target, _, index):

        expr(target, ExternRef)
          .concat([I32Const(index)])
          .concat(call(cls.imports.findStaticByName('wasmix.runtime.Enums', 'param', enumParam(e.t))));        

      case TField(_, FEnum(_.get() => enm, ef)):

        call(cls.imports.find(Static(enm, ef.name, Get(e.t)), e.pos));

      case TCall(ctor = { expr: TField(_, FEnum(_.get() => enm, ef)) }, args):

        final fn = FunctionType.of(ctor.t, args.length, e.t);

        [for (pos => a in args) for (i in expr(a, fn.args[pos].valueType)) i]
          .concat(call(cls.imports.find(Static(enm, ef.name, Method(fn)), e.pos)));

      default: null;
    }
  }

  function enumParam(t:Type) {
    return PARAM.type.applyTypeParameters(PARAM.params, [t]);
  }

  static final RUNTIME = 'wasmix.runtime.Enums';
  static final PARAM = Imports.resolveStaticField(RUNTIME, 'param');
  static final INDEX = Context.typeof(macro $p{RUNTIME.split('.')}.index);
}