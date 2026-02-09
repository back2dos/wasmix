package wasmix.compiler.plugins;

class Arrays extends Plugin {

  function asArrayUpdate(e:TypedExpr) {
    return asUpdateOf(e, (e, kind) -> switch e.expr {
      case TArray(arr, index):
        Some({ 
          arr: arr, 
          index: index, 
          value: switch kind {
            case Assign(v),AssignOp(v, _): v;
            case Bump(up, postFix): Context.typeExpr(macro $v{if (up) 1 else -1});
          },
          method: switch kind {
            case Assign(_): 'set';
            case AssignOp(_, op): op.getName().toLowerCase().substr(2);
            case Bump(_, postFix): if (postFix) 'andBump' else 'bumped';
          }
        });
      default: None;
    });
  }

  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case asArrayUpdate(e) => Some({ arr: arr, index: index, value: value, method: method }):

        rec(arr);
        rec(index);
        rec(value);

        cls.imports.addStaticByName(RUNTIME, method, update(arr.t, value.t));

      case TArray(arr, index):

        rec(arr);
        rec(index);

        cls.imports.addStaticByName(RUNTIME, 'get', get(arr.t, e.t));

      case TArrayDecl(values):

        for (v in values) rec(v);

        cls.imports.addStaticByName(RUNTIME, 'literal', literal(e.t, values.length));
        
      default: false;
    }
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {

    function call(id) return this.call(id, e, expected);

    return switch e.expr {
      case asArrayUpdate(e) => Some({ arr: arr, index: index, value: value, method: method }):
        
        expr(arr, ExternRef)
          .concat(expr(index, I32))
          .concat(expr(value, cls.type(value.t, value.pos)))
          .concat(call(cls.imports.findStaticByName(RUNTIME, method, update(arr.t, value.t))));

      case TArray(arr, index):

        expr(arr, ExternRef)
          .concat(expr(index, I32))
          .concat(call(cls.imports.findStaticByName(RUNTIME, 'get', get(arr.t, e.t))));

      case TArrayDecl(values):

        final expected = switch e.t {
          case TInst(_.get() => { pack: [], name: 'Array' }, [t]): cls.type(t, e.pos);
          default: throw 'assert';
        }

        [for (v in values) for (i in expr(v, expected)) i]
          .concat(call(cls.imports.findStaticByName(RUNTIME, 'literal', literal(e.t, values.length))));

      default: null;
    }
  }

  static final RUNTIME = 'wasmix.runtime.Arrays';

  function get(arr:Type, el:Type) {
    return new FunctionType([{ name: 'arr', type: arr, valueType: ExternRef }, { name: 'index', type: Context.getType('Int'), valueType: I32 }], el);
  }

  function update(arr:Type, value:Type) {
    return new FunctionType([{ name: 'arr', type: arr, valueType: ExternRef }, { name: 'index', type: Context.getType('Int'), valueType: I32 }, { name: 'value', type: value, valueType: toValueType(value) }], value);
  }

  function literal(t:Type, arity:Int) {
    final el = switch t {
      case TInst(_.get() => { pack: [], name: 'Array' }, [t]): t;
      default: throw 'assert';
    }
    return new FunctionType([for (i in 0...arity) { name: 'v${i}', type: el, valueType: toValueType(el) }], t);
  }
}