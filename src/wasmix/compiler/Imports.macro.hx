package wasmix.compiler;

class Imports {
  final indices = new Map<String, Int>();
  final imports = new Array<Import>();
  final modules = new Map<String, Array<ObjectField>>();
  final scope:ClassScope;

  public function count() return imports.length;

  public function new(scope) {
    this.scope = scope;
  }

  public function all()
    return imports;

  public function toExpr():Expr {
    return {
      expr: EObjectDecl([for (module => fields in modules) {
        field: module,
        quotes: Quoted,
        expr: { expr: EObjectDecl(fields), pos: (macro _).pos },
      }]),
      pos: (macro _).pos,
    }
  }
  
  function key(cls:BaseType, f:{ name:String, type:Type, pos:Position }, t:Type) {
    return '${ClassScope.typeId(cls)}::${f.name}::${t.toString()}';
  }
  
  function add(key:String, t:Type, module:String, name:String, pos:Position, expr:(isConst:Bool) -> Expr) {
    return indices[key] ??= {
      var ret = t;
      var isConst = false;
      var args = switch Context.follow(t) {
        case TFun(args, t):
          ret = t;
          args;
        case v:
          ret = t;
          isConst = true;
          [];
      }

      (modules[module] ??= []).push({
        field: name,
        expr: expr(isConst),
      });

      imports.push({
        module: module, 
        name: name,
        kind: ImportFunction(scope.signature([for (a in args) a.t], ret, pos)),
      }) - 1;
    }
  }

  function _add(module:String, name:String, payload:() -> { args:Array<Type>, ret:Type, expr:Expr }) {
    return indices['${module}::${name}'] ??= {

      final payload = payload();

      (modules[module] ??= []).push({
        field: name,
        expr: payload.expr,
      });

      imports.push({
        module: module, 
        name: name,
        kind: ImportFunction(scope.signature(payload.args, payload.ret, payload.expr.pos)),
      }) - 1;
    }
  }

  static function id(name:String, field:InstanceField) 
    return switch field {
      case Method(t): '${name}:${t.id()}';
      case Get(t): 'get.$name:${t.toString()}';
    }

  public function findField(receiver:Type, name:String, field:InstanceField, pos:Position) {
    final id = id(name, field);
    final key = '${receiver.toString()}::${id}';
    return indices[key] ?? Context.error('${id} not found', pos);
  }

  public function addField(receiver:Type, name:String, field:InstanceField, pos:Position) {
    _add(receiver.toString(), id(name, field), () -> switch field {
      case Method(t): 
        final callArgs = [for (a in t.args) macro $i{a.name}];

        { 
          args: [receiver].concat([for (a in t.args) a.type]), 
          ret: t.ret, 
          expr: {
            {
              pos: pos,
              expr: EFunction(null, {
                args: [{ name: 'self', type: receiver.toComplexType() }].concat([for (a in t.args) { name: a.name, type: a.type.toComplexType() }]),
                ret: t.ret.toComplexType(),
                expr: macro return self.$name($a{callArgs}),
              }),
            }
          }
        };
      case Get(t): 
        final self = receiver.toComplexType(),
              ret = t.toComplexType();
        { 
          args: [receiver], 
          ret: t, 
          expr: macro function (self:$self):$ret return self.$name 
        };
    });
  }

  public function addStatic(cls, f, t, ?pos) {
    return add(key(cls, f, t ??= f.type), t, ClassScope.typeId(cls), f.name, pos ?? f.pos, (isConst) -> {
      var callee = macro @:privateAccess $p{cls.module.split('.').concat([cls.name, f.name])};
      if (isConst) macro () -> $callee;
      else callee;
    });
  }

  public function findStatic(cls, f, t) {
    return indices[key(cls, f, t ??= f.type)] ?? Context.error('${cls.name}.${f.name}:${t.toString()} not found', f.pos);
  }

  static final classes = new Map();

  static function resolve(cls:String, field:String) {
    final all = classes[cls] ??= switch Context.getType(cls) {
      case TInst(_.get() => c, _): { cl: c, statics: c.statics.get() };
      default: throw '$cls is not a class';
    }

    for (f in all.statics) 
      if (f.name == field) return { cl: all.cl, f: f };
    
    throw 'Unknown field $cls.$field';
  }

  static public function resolveStaticField(cls:String, field:String) {
    return resolve(cls, field).f;
  }

  public function addStaticByName(cls:String, field:String, t) {
    final resolved = resolve(cls, field);

    return addStatic(resolved.cl, resolved.f, t);
  }
  
  public function findStaticByName(cls, field, t) {
    final resolved = resolve(cls, field);
    return findStatic(resolved.cl, resolved.f, t);
  }

}

enum InstanceField {
  Method(t:FunctionType);
  Get(t:Type);
  // Set(t:Type, op:Null<Binop>); // TODO: implement
}