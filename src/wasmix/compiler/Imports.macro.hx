package wasmix.compiler;

class Imports {
  final indices = new Map<String, Int>();
  final imports = new Array<Import>();
  final modules = new Map<String, Array<ObjectField>>();
  final scope:ClassScope;

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

  function key(cls:ClassType, f:ClassField) {
    return '${ClassScope.classId(cls)}::${f.name}';
  }

  public function addStatic(cls, f) {
    final key = key(cls, f);
    return indices[key] ??= switch f.type {
      case TFun(args, ret):
        final module = ClassScope.classId(cls);// TODO: allow short names

        (modules[module] ??= []).push({
          field: f.name,
          expr: macro $p{cls.module.split('.').concat([cls.name, f.name])},
        });
        imports.push({
          module: module, 
          name: f.name,
          kind: ImportFunction(scope.signature([for (a in args) a.t], ret, f.pos)),
        }) - 1;
      default: throw 'assert';
    }
  }
}