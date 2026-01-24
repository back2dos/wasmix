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

  public function addStatic(cls, f, t, ?pos) {
    return indices[key(cls, f, t ??= f.type)] ??= {
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

      final module = ClassScope.typeId(cls);// TODO: allow short names

      (modules[module] ??= []).push({
        field: f.name,
        expr: {
          var callee = macro @:privateAccess $p{cls.module.split('.').concat([cls.name, f.name])};
          if (isConst) macro () -> $callee;
          else callee;
        }
      });

      imports.push({
        module: module, 
        name: f.name,
        kind: ImportFunction(scope.signature([for (a in args) a.t], ret, pos ?? f.pos)),
      }) - 1;
    }
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