package wasmix.compiler;

class Imports {
  final strings = [];
  final functionIndices = new Map<String, Int>();
  final globalIndices = new Map<String, Int>();
  final imports = new Array<Import>();
  final modules = new Map<String, Array<ObjectField>>();
  final scope:ClassScope;

  var functionCount = 0;
  var globalCount = 0;

  public function count() return functionCount;

  public function new(scope) {
    this.scope = scope;
  }

  public function all() return imports;

  public function toExpr():Expr {
    return {
      expr: EObjectDecl([for (module => fields in modules) {
        field: module,
        expr: { expr: EObjectDecl(fields), pos: (macro _).pos },
      }]),
      pos: (macro _).pos,
    }
  }
  
  function addIfNeeded(module:String, name:String, payload:() -> { expr:Expr, kind:ImportKind }) {
    final key = '${module}::${name}';

    if (functionIndices.exists(key) || globalIndices.exists(key)) return;
    
    final payload = payload();

    (modules[module] ??= []).push({
      field: name,
      expr: payload.expr,
    });

    imports.push({
      module: module, 
      name: name,
      kind: payload.kind,
    });

    switch payload.kind {
      case ImportFunction(_): functionIndices[key] = functionCount++;
      case ImportGlobal(_): globalIndices[key] = globalCount++;
      default: throw 'Unsupported import kind';
    }
  }

  static final shortModules = new Shortener();
  static final shortIds = new Shortener();

  static function module(i:MemberImport) {
    return shortModules.get(switch i {
      case Static(b, _): b.pack.concat([b.name]).join('.');
      case Field(receiver, _): receiver.toString();
      case Constructor(c, _): c.pack.concat([c.name]).join('.');
    });
  }

  static function id(i:MemberImport) {
    function field(name:String, f:FieldKind) {
      return switch f {
        case Method(t): '${name}:${t.id()}';
        case Get(t): 'get.${name}:${t.toString()}';
      }
    }

    return shortIds.get(switch i {
      case Static(b, name, f): field(name, f);
      case Field(receiver, name, f): field(name, f);
      case Constructor(c, t): 'new:${t.id()}';
    });
  }

  public function addString(s:String) {
    final id = switch strings.indexOf(s) {
      case -1: strings.push(s) - 1;
      case v: v;
    }

    addIfNeeded('STRINGS', '$id', () -> {
      expr: macro $v{s},
      kind: ImportGlobal({
        valueType: ExternRef,
        mutable: false,
      }),
    });
  }

  public function findString(s:String) {
    final idx = strings.indexOf(s);
    if (idx == -1) throw 'String $s not found';
    return globalIndices['STRINGS::$idx'];
  }

  public function find(i:MemberImport, pos:Position) {
    final key = '${module(i)}::${id(i)}';
    return functionIndices[key] ?? Context.error('${key} not found', pos);
  }

  public function add(i:MemberImport, pos:Position) {
    function method(callee:Expr, name:String, t:FunctionType, prefix:Array<FunctionType.FunctionTypeArg>):MethodImport {
      final callArgs = [for (a in t.args) scope.fromWASM(macro $i{a.name}, a.type)];
      final args = prefix.concat(t.args);

      return { 
        args: [for (a in args) a.type], 
        ret: t.ret, 
        expr: {
          {
            pos: pos,
            expr: EFunction(null, {
              args: [for (a in args) { name: a.name, type: a.type.toComplexType() }],
              ret: t.ret.toComplexType(),
              expr: macro return ${scope.toWASM(macro @:privateAccess $callee.$name($a{callArgs}), t.ret)},
            }),
          }
        }
      };
    }

    function get(owner:Expr, name:String, t:Type, args:Array<FunctionType.FunctionTypeArg>):MethodImport {
      return { 
        args: [for (a in args) a.type], 
        ret: t, 
        expr: {
          {
            pos: pos,
            expr: EFunction(null, {
              args: [for (a in args) { name: a.name, type: a.type.toComplexType() }],
              ret: t.toComplexType(),
              expr: macro return ${scope.toWASM(macro @:privateAccess $owner.$name, t)},
            }),
          }
        }
      };
    }

    addIfNeeded(module(i), id(i), () -> {
      final m = switch i {
        case Constructor(c, t): 
          final callArgs = [for (a in t.args) scope.toWASM(macro $i{a.name}, a.type)];

          final path:TypePath = {
            pack: c.pack,
            name: c.name,
            sub: c.name,
            params: [],            
          }

          {
            args: [for (a in t.args) a.type],
            ret: t.ret,
            expr: {
              pos: pos,
              expr: EFunction(null, {
                args: [for (a in t.args) { name: a.name, type: a.type.toComplexType() }],
                ret: t.ret.toComplexType(),
                expr: macro return new $path($a{callArgs}),
              }),
            }
          }
        case Static(b, name, Method(t)): 
          method(macro $p{b.module.split('.').concat([b.name])}, name, t, []);
        case Static(b, name, Get(t)): 
          get(macro $p{b.module.split('.').concat([b.name])}, name, t, []);
        case Field(receiver, name, Method(t)): 
          method(scope.fromWASM(macro self, receiver), name, t, [{ name: 'self', type: receiver }]);  
        case Field(receiver, name, Get(t)): 
          get(macro self, name, t, [{ name: 'self', type: receiver }]);
      }

      {
        expr: m.expr,
        kind: ImportFunction(scope.signature(m.args, m.ret, m.expr.pos)),
      }
    });
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

  public function addStaticByName(cls:String, field:String, t:NamedStatic) {
    final resolved = resolve(cls, field);

    return add(Static(resolved.cl, field, t), resolved.f.pos);
  }
  
  public function findStaticByName(cls, field, t:NamedStatic) {
    final resolved = resolve(cls, field);
    return find(Static(resolved.cl, field, t), resolved.f.pos);
  }
}

abstract NamedStatic(FieldKind) from FieldKind to FieldKind {
  inline function new(v) this = v;

  @:from static function fromType(t:Type) return new NamedStatic(switch FunctionType.maybe(t, null) {
    case Some(v): Method(v);
    case None: Get(t);
  });
  @:from static function functionType(t:FunctionType) return new NamedStatic(Method(t));
}

enum FieldKind {
  Method(t:FunctionType);
  Get(t:Type);
  // Set(t:Type, op:Null<Binop>); // TODO: implement
}

enum MemberImport {
  Static(b:BaseType, name:String, f:FieldKind);
  Field(receiver:Type, name:String, f:FieldKind);
  Constructor(c:ClassType, t:FunctionType);
}

private typedef MethodImport = { args:Array<Type>, ret:Type, expr:Expr };

private class Shortener {
  final ids = new Map<String, String>();
  var count = 0;

  public function new() {}
  public function get(s) {
    return 
      #if wasmix.minify.imports 
        ids[s] ??= Helpers.shortIdent(count++)
      #else 
        s 
      #end
    ;
  }
}