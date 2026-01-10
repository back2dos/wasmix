package wasmix.compiler;

class ClassScope {

  final methods = new Array<MethodScope>();
  final methodIndices = new Map<String, Int>();
  final types = new Array<FunctionType>();
  final typeIndices = new Map<String, Int>();

  public function new(pos:Position, cl:ClassType) {

    for (f in cl.statics.get()) switch f.kind {
      case FMethod(MethNormal) if (f.isPublic):
        
        methodIndices[f.name] = methods.length;

        switch f.expr() {
          case { expr: TFunction(fn) }:
            methods.push(new MethodScope(this, f, fn));
          default:
            throw 'assert';
        }
      default:
    }
  }

  public inline function getFunctionId(name:String) {
    return methodIndices[name];
  }

  public function signature(args:Array<Type>, ret:Type, pos:Position) {
    return 
      typeIndices[args.concat([ret]).map(t -> t.toString()).join(' -> ')] ??= (
        types.push({
          params: [for (a in args) type(a, pos)],
          results: switch Context.followWithAbstracts(ret) {
            case TAbstract(_.toString() => 'Void', _): [];
            case t: [type(t, pos)];
          },
        }) - 1
      );
  }

  public function transpile():Module {
    return {
      functions: [for (method in methods) method.transpile()],
      exports: [for (method in methods) {
        name: method.field.name,
        kind: ExportFunction(methodIndices[method.field.name])
      }],
      types: types,
    }
  }

  public function type(t:Type, pos:Position) {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(a, _): 
        switch a.toString() {
          case "Bool" | "Int": I32;
          case "Float": F64;
          default: Context.error('Unsupported type ${a.toString()}', pos);
        }
      case TFun(args, ret): ExternRef;
      default: Context.error('Unsupported type ${t.toString()}', pos);
    }
  }

  public function exports() {
    return ComplexType.TAnonymous([for (method in methods) {
      name: method.field.name,
      pos: method.field.pos,
      kind: FFun({
        args: [
          for (a in method.fn.args) {
            name: a.v.name,
            type: Context.toComplexType(a.v.t),
          }
        ],
        ret: Context.toComplexType(method.fn.t),
      }),
    }]);
  }
}