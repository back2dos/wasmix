package wasmix.compiler.plugins;

import wasmix.runtime.BufferViewType;
import wasmix.compiler.plugins.BinOps;

class BufferViews extends Plugin {

  static function isBufferView(e:TypedExpr) return getType(e.t) != None;

  override public function scan(e:TypedExpr, rec:TypedExpr->Void):Bool {
    return switch e.expr {
      case asBufferViewUpdate(e) => Some({ target: target, index: index }):
        rec(target);
        rec(index);
        true;
      case TField(target, _) if (isBufferView(target)):
        rec(target);
        true;
      case TArray(target, index) if (isBufferView(target)):
        rec(target);
        rec(index);
        true;
      // case TCall({ expr: TField(target, _) }, args) if (isBufferView(target)):
      //   rec(target);
      //   for (a in args) rec(a);
      //   true;
      default: false;
    }
  }

  function getStart(target:TypedExpr, kind:BufferViewType) {
    return expr(target, I64).concat([I32WrapI64]);
  }

  function offset(target:TypedExpr, index:TypedExpr, kind:BufferViewType) {
    final width = kind.width;
    
    return getStart(target, kind)
      .concat(expr(index, I32))
      .concat(width == 1 ? [] : [I32Const(width), I32Mul])
      .concat([I32Add]);
  }

  static function valueType(kind:BufferViewType) {
    return switch kind {
      case Float32: F32;
      case Float64: F64;
      default: I32;
    }
  }

  function asBufferViewUpdate(e:TypedExpr) {
    return asUpdateOf(e, (e, update) -> switch e.expr {
      case TArray(target = getType(_.t) => Some(kind), index):
        Some({ target: target, index: index, kind: kind, update: update });
      default: None;
    });
  }

  override public function translate(e:TypedExpr, expected:Null<ValueType>):Null<Expression> {
    return switch e.expr {
      case asBufferViewUpdate(e) => Some({ target: target, index: index, kind: kind, update: update }):
        
        final valueType = valueType(kind);

        function store(?dup) {

          dup ??= expected != null;

          final ret = switch kind {
            case Uint8: I32Store8;
            case Int8: I32Store8;
            case Uint16: I32Store16;
            case Int16: I32Store16;
            case Uint32: I32Store;
            case Int32: I32Store;
            case Float32: F32Store;
            case Float64: F64Store;
          }
      
          final instruction = ret(0, kind.alignment);

          return 
            if (dup) m.dup(valueType).concat([instruction]).concat(coerce(valueType, expected, e.pos));
            else [instruction];
        }

        switch update {
          case Bump(up, postFix):
            final ret = offset(target, index, kind)
              .concat(m.dup(I32))
              .concat([load(kind)]);

            final compute = [I32Const(1), up ? I32Add : I32Sub];

            switch [expected, postFix] {
              case [null, _] | [_, false]:
                ret.concat(compute).concat(store());
              default:
                ret.concat(m.dup(valueType)).concat(compute).concat(store(false));
            }
          case Assign(v):
            offset(target, index, kind)
              .concat(expr(v, valueType))
              .concat(store());// TODO: put on stack if expected is not null

          case AssignOp(v, op):
            final opType = BinOpType.forBuffer(kind).with(BinOpType.ofExpr(v), valueType);
            
            offset(target, index, kind)
              .concat(m.dup(I32))
              .concat([load(kind)])
              .concat(expr(v, opType.toValueType()))
              .concat([opType.getInstruction(op, e.pos)])
              .concat(store()); // TODO: put on stack if expected is not null    
        }

      case TArray(target = getType(_.t) => Some(kind), index):

        offset(target, index, kind).concat([load(kind)]).concat(coerce(valueType(kind), expected, e.pos));

      case TField(target = getType(_.t) => Some(kind), FInstance(_, _, _.get().name => name)):

        function length() 
          return expr(target, I64).concat([I64Const(32), I64ShrU, I32WrapI64]);
  
        final ret = 
          switch name {
            case 'byteLength':
              switch kind.alignment {
                case 0: length();
                case v: length().concat([I32Const(v), I32Shl]);
              }
            case 'byteOffset':
              getStart(target, kind);
            case 'length':
              length();
            default: 
              error('Cannot access $name in WASM', e.pos);
          }

         ret.concat(coerce(I32, expected, e.pos));

      default: null;
    }
  }

  static function load(t:BufferViewType) {
    final ret = switch t {
      case Uint8: I32Load8U;
      case Int8: I32Load8S;
      case Uint16: I32Load16U;
      case Int16: I32Load16S;
      case Uint32: I32Load;
      case Int32: I32Load;
      case Float32: F32Load;
      case Float64: F64Load;
    }

    return ret(0, t.alignment);
  }

  static final BY_NAME = [for (a in BufferViewType.ALL) '${a}Array' => a];

  static public function getType(c:Classy) {
    return switch c.get() {
      case Some({ pack: ['wasmix', 'runtime'], name: BY_NAME[_] => kind }) if (kind != null):
        Some((kind:BufferViewType));
      default:
        None;
    } 
  }
}

abstract Classy(Option<ClassType>) {
  inline function new(v) this = v;
  public function get() return this;
  public function map<T>(f:ClassType -> T):Option<T> return switch this {
    case Some(v): Some(f(v));
    case None: None;
  }
  public function flatMap<T>(f:ClassType -> Option<T>):Option<T> return switch this {
    case Some(v): f(v);
    case None: None;
  }
  
  @:from static function ofRef(r:Ref<ClassType>) return new Classy(
    if (r == null) None
    else switch r.get() {
      case null: None;
      case c: Some(c);
    }
  );

  @:from static function ofType(v:Type) return new Classy(switch Context.followWithAbstracts(v) {
    case TInst(c, _): Some(c.get());
    default: None;
  });
}