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
          case "wasmix.runtime.Float32": F32;
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

  public function exportsShape() {
    return ComplexType.TAnonymous(
      [for (m in methods) {
        name: m.field.name,
        pos: m.field.pos,
        kind: FFun({
          args: [
            for (a in m.fn.args) {
              name: a.v.name,
              type: Context.toComplexType(a.v.t),
            }
          ],
          ret: Context.toComplexType(m.fn.t),
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

  static final EXPORTS = "exports";

  public function exports(exports:Expr) {
    final shape = exportsShape();
    final fields = [
      for (m in methods)
        if (m.fn.args.exists(a -> BufferView.getType(a.v.t) != None)) {
          final name = m.field.name,
                mapped = [for (a in m.fn.args) switch BufferView.getType(a.v.t) {
                  case Some(type): macro cast $i{EXPORTS}.memory.toWASM($i{a.v.name});
                  case None: macro $i{a.v.name};
                }];
          ({
            field: name,
            expr: { 
              expr: EFunction(null, {
                args: [for (a in m.fn.args) { name: a.v.name, type: Context.toComplexType(a.v.t) }],
                ret: Context.toComplexType(m.fn.t),
                expr: {
                  var body = macro $i{EXPORTS}.$name($a{mapped});
                  switch Context.followWithAbstracts(m.fn.t) {
                    case TAbstract(_.toString() => 'Void', _): body;
                    case BufferView.getType(_) => Some(type): macro return cast $i{EXPORTS}.memory.fromWASM(cast $body, $p{['wasmix', 'runtime', '${type}Array']}.new);
                    default: macro return $body;
                  }
                }
              }), 
              pos: m.field.pos 
            },
          }:ObjectField);
        }
    ];

    return switch fields {
      case []:
        exports;
      case fields:
        macro { 
          final $EXPORTS:$shape = cast $exports; 
          js.lib.Object.assign({}, $i{EXPORTS}, ${{ expr: EObjectDecl(fields), pos: (macro _).pos }});
        }
    }
  }
}