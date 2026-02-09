package wasmix.compiler;

import wasmix.compiler.plugins.BufferViews;

class ClassScope {

  static public function typeId(cl:BaseType)
    return '${cl.module}.${cl.name}';

  final methods = new Array<MethodScope>();
  final methodIndices = new Map<String, Int>();
  final types = new Array<FunctionSignature>();
  final typeIndices = new Map<String, Int>();

  public final name:String;
  public final imports:Imports;

  public function new(pos:Position, cl:ClassType) {
    this.name = typeId(cl);
    this.imports = new Imports(this);

    switch cl.constructor {
      case null:
      case _.get() => ctor: error('Constructor is not supported', ctor.pos);
    }


    for (f in cl.statics.get()) switch f.kind {
      case FMethod(MethNormal):        
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
          results: switch retType(ret, pos) {
            case null: [];
            case v: [v];
          }
        }) - 1
      );
  }

  public function retType(t:Type, pos:Position) {
    return switch Context.followWithAbstracts(t) {
      case TAbstract(_.toString() => 'Void', _): null;
      case t: type(t, pos);
    }
  }

  public function transpile():Module {
    final prepared = [for (method in methods) method.prepare()];
    
    final offset = imports.count();

    for (i => m in methods) methodIndices[m.field.name] = i + offset;
    
    return {
      functions: [for (generate in prepared) generate()],
      memories: [
        {
          limits: {
            min: 1,
            max: null,
          },
        }
      ],
      exports: [for (method in methods) if (method.field.isPublic) {
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
    return toValueType(t, pos);
  }

  public function exportsShape() {
    return ComplexType.TAnonymous(
      [for (m in methods) if (m.field.isPublic) {
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

  public function toWASM(e:Expr, t:Type) {
    return switch BufferViews.getType(t) {
      case Some(_): macro cast $i{EXPORTS}.memory.toWASM($e);
      case None: e;
    }
  }

  public function fromWASM(e:Expr, t:Type) {
    return switch BufferViews.getType(t) {
      case Some(type): macro cast $i{EXPORTS}.memory.fromWASM(cast $e, $p{['wasmix', 'runtime', '${type}Array']}.new);
      case None: 
        switch Context.followWithAbstracts(t) {
          case TAbstract(_.toString() => 'Bool', _): macro (cast $e) != 0;
          case t: e;
        }
    }
  }

  static final EXPORTS = "exports";

  public function exports(exports:Expr) {
    final shape = exportsShape();
    final fields = [
      for (m in methods) if (m.field.isPublic) {
        var changed = false;

        function toWASM(e, t) {
          var ret = this.toWASM(e, t);
          if (ret != e) changed = true;
          return ret;
        }

        function fromWASM(e, t) {
          var ret = this.fromWASM(e, t);
          if (ret != e) changed = true;
          return ret;
        }

        final name = m.field.name,
              mapped = [for (a in m.fn.args) toWASM(macro $i{a.v.name}, a.v.t)];

        var ret = {
          var body = macro $i{EXPORTS}.$name($a{mapped});
          switch Context.followWithAbstracts(m.fn.t) {
            case TAbstract(_.toString() => 'Void', _): body;
            case t: macro return ${fromWASM(body, t)};
          }
        }

        if (!changed) continue;

        ({
          field: name,
          expr: { 
            expr: EFunction(null, {
              args: [for (a in m.fn.args) { name: a.v.name, type: Context.toComplexType(a.v.t) }],
              ret: Context.toComplexType(m.fn.t),
              expr: ret,
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