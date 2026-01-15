package wasmix.compiler;

import wasmix.compiler.BufferView;

class ClassScope {

  static public function typeId(cl:BaseType)
    return '${cl.module}.${cl.name}';

  final methods = new Array<MethodScope>();
  final methodIndices = new Map<String, Int>();
  final types = new Array<FunctionType>();
  final typeIndices = new Map<String, Int>();

  public final name:String;
  public final imports:Imports;

  public function new(pos:Position, cl:ClassType) {
    this.name = typeId(cl);
    this.imports = new Imports(this);

    for (f in cl.statics.get()) switch f.kind {
      case FMethod(MethNormal) if (f.isPublic):        
        switch f.expr() {
          case { expr: TFunction(fn) }:
            methods.push(new MethodScope(this, f, fn));
          default:
            throw 'assert';
        }
      default:
    }

    final offset = imports.count();
    
    for (i => m in methods) methodIndices[m.field.name] = i + offset;
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

  public function isSelf(cls:ClassType)
    return ClassScope.typeId(cls) == name;

  public function transpile():Module {
    return {
      functions: [for (method in methods) method.transpile()],
      memories: [
        {
          limits: {
            min: 1,
            max: null,
          },
        }
      ],
      exports: [for (method in methods) {
        name: method.field.name,
        kind: ExportFunction(methodIndices[method.field.name])
      }].concat([
        {
          name: 'memory',
          kind: ExportMemory(0),
        }
      ]),
      imports: imports.all(),
      types: types,
    }
  }

  public function type(t:Type, pos:Position) {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(a, _): 
        switch a.toString() {
          case "Bool" | "Int": I32;
          case "Float": F64;
          case "EnumValue": ExternRef;
          default: Context.error('Unsupported type ${a.toString()}', pos);
        }
      case TInst(c = _.get() => { kind: KTypeParameter(_) }, _): Context.error('Type parameter $c not supported', pos);
      case TInst(BufferView.getType(_) => Some(kind), _): I64;
      case TDynamic(_) | TEnum(_) | TInst(_): ExternRef;
      default: Context.error('Unsupported type ${t.toString()}', pos);
    }
  }

  public function exports() {
    return ComplexType.TAnonymous(
      [for (method in methods) {
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
      }]
      .concat([{
        name: 'memory',
        pos: switch Context.getType('wasmix.runtime.Memory') {
          case TAbstract(_.get().pos => pos, _): pos;
          default: throw 'assert';
        },
        kind: FVar(macro : wasmix.runtime.Memory, null),
      }]),
    );
  }
}