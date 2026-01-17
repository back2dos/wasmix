package wasmix.compiler;

import wasmix.compiler.BinOps;
import haxe.ds.Option;
import wasmix.runtime.BufferViewType;

class BufferView {
  final target:TypedExpr;
  final index:TypedExpr;
  final type:BufferViewType;

  function new(target, index, type) {
    this.target = target;
    this.index = index;
    this.type = type;
  }

  function offset(m:MethodScope) {
    final width = type.width;
    
    return m.expr(target)
      .concat([I32WrapI64])
      .concat(m.expr(index))
      .concat(width == 1 ? [] : [I32Const(width), I32Mul])
      .concat([I32Add]);
  }

  public function get(m) {
    return offset(m).concat([load(type)]);
  }

  public function set(m:MethodScope, v:TypedExpr) {
    return offset(m)
      .concat([load(type)])
      .concat(m.expr(v))
      .concat([store(type)]);
  }

  public function update(m:MethodScope, op:Binop, v:TypedExpr, pos) {
    return offset(m)
      .concat(m.dup(I32))
      .concat([load(type)])
      .concat(m.expr(v))
      .concat([OpType.forBuffer(type).with(OpType.ofExpr(v)).getInstruction(op, pos)])
      .concat([store(type)]);    
  }

  static public function access(e:TypedExpr) {
    return switch e.expr {
      case TArray(target = { t: TInst(getType(_) => Some(type), _) }, index):
        Some(new BufferView(target, index, type));
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

  static function store(t:BufferViewType) {
    final ret = switch t {
      case Uint8: I32Store8;
      case Int8: I32Store8;
      case Uint16: I32Store16;
      case Int16: I32Store16;
      case Uint32: I32Store;
      case Int32: I32Store;
      case Float32: F32Store;
      case Float64: F64Store;
    }

    return ret(0, t.alignment);
  }

  static final BY_NAME = [for (a in BufferViewType.ALL) '${a}Array' => a];

  static public function getType(c:Classy) {
    return switch c.get() {
      case Some({ pack: ['js', 'lib'], name: BY_NAME[_] => kind }) if (kind != null):
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

  @:from static function ofType(v:Type) return new Classy(switch Context.follow(v) {
    case TInst(c, _): Some(c.get());
    default: None;
  });
}