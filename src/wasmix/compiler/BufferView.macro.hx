package wasmix.compiler;

import wasmix.compiler.BinOps;
import haxe.ds.Option;
import wasmix.runtime.BufferViewType;

class BufferView {
  final m:MethodScope;
  final target:TypedExpr;
  final index:TypedExpr;
  final type:BufferViewType;
  final valueType:ValueType;
  final pos:Position;

  function new(m, target, index, type, pos) {
    this.m = m;
    this.target = target;
    this.index = index;
    this.type = type;
    this.pos = pos;
    this.valueType = switch type {
      case Float32: F32;
      case Float64: F64;
      default: I32;
    }
  }

  function offset() {
    final width = type.width;
    
    // LICM: Use cached base pointer if available (for function parameters)
    final basePtr:Expression = switch target.expr {
      case TLocal(v):
        switch m.getCachedBasePtr(v.id) {
          case null: m.expr(target, I64).concat([I32WrapI64]);
          case basePtrLocalId: [LocalGet(basePtrLocalId)];
        }
      default:
        m.expr(target, I64).concat([I32WrapI64]);
    };
    
    return basePtr
      .concat(m.expr(index, I32))
      .concat(width == 1 ? [] : [I32Const(width), I32Mul])
      .concat([I32Add]);
  }

  public function get(expected:Null<ValueType>) {
    return offset().concat([load(type)]).concat(m.coerce(valueType, expected, pos));
  }

  public function set(v:TypedExpr, expected:Null<ValueType>) {
    return offset()
      .concat(m.expr(v, valueType))
      .concat(store(expected));
  }

  public function update(op:Binop, v:TypedExpr, expected:Null<ValueType>) {
    final opType = OpType.forBuffer(type).with(OpType.ofExpr(v), valueType);
    return offset()
      .concat(m.dup(I32))
      .concat([load(type)])
      .concat(m.expr(v, opType.toValueType()))
      .concat([opType.getInstruction(op, pos)])
      .concat(store(expected));    
  }

  static public function access(m:MethodScope, e:TypedExpr) {
    return switch e.expr {
      case TArray(target = { t: TInst(getType(_) => Some(type), _) }, index):
        Some(new BufferView(m, target, index, type, e.pos));
      default: None;
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

  function store(expected:Null<ValueType>) {
    final ret = switch type {
      case Uint8: I32Store8;
      case Int8: I32Store8;
      case Uint16: I32Store16;
      case Int16: I32Store16;
      case Uint32: I32Store;
      case Int32: I32Store;
      case Float32: F32Store;
      case Float64: F64Store;
    }

    final instruction = ret(0, type.alignment);

    return switch m.coerce(valueType, expected, pos) {
      case [Drop]: [instruction];
      case e: m.dup(valueType).concat([instruction]).concat(e);
    }
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