package wasmix.compiler.plugins;

class Locals extends Plugin {
  var varIdCounter = 0;

  final varIds = new Map<Int, Int>();
  final types = new Array<ValueType>();
  final tmpIds = new Map<ValueType, Int>();

  public function new(m) {
    super(m);

    for (a in m.fn.args) varIds[a.v.id] = varIdCounter++;
  }

  public function tmp(t:ValueType) {
    return tmpIds[t] ??= {
      final id = varIdCounter++;
      types.push(t);
      id;
    }
  }

  public inline function varId(v:TVar) {
    return varIds[v.id];
  }

  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case TVar(v, init): 
        varIds[v.id] = varIdCounter++;
        types.push(type(v.t, e.pos));
        rec(init);
        true;
      default: false;
    }
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e.expr {
      case asUpdate(e) => Some({ target: target = { expr: TLocal(v) }, kind: update }): 
        function store(?dup) {
          dup ??= expected != null;
          return 
            if (dup) m.dup(type(v.t, e.pos)).concat([LocalTee(varId(v))]).concat(coerce(type(v.t, e.pos), expected, e.pos));
            else [LocalSet(varId(v))];
        }

        switch update {
          case Bump(up, postFix):
            final ret = [LocalGet(varId(v))];
            final compute = [I32Const(1), up ? I32Add : I32Sub];

            switch [expected, postFix] {
              case [null, _] | [_, false]:
                ret.concat(compute).concat(store());
              default:
                ret.concat(m.dup(type(v.t, e.pos))).concat(compute).concat(store(false));
            }
          case Assign(value):
            expr(value, type(v.t, e.pos)).concat(store());
          case AssignOp(value, op):
            m.binOps.make(op, target, value, type(v.t, target.pos), e.pos).concat(store());
        }
      case TLocal(v): 
        switch expected {
          case null: [];
          default: [LocalGet(varId(v))].concat(coerce(type(v.t, e.pos), expected, e.pos));
        }
      case TVar(v, e): 
        if (e == null) [];
        else {
          final ret = expr(e, type(v.t, e.pos));
          ret.push(LocalSet(varId(v)));
          ret;
        }
      default: null;
    }
  }
}