package wasmix.compiler;

import wasmix.compiler.plugins.BufferViews;

private final FIRST = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
private final LATER = FIRST + '0123456789';

function shortIdent(i:Int) {
  var ret = FIRST.charAt(i % FIRST.length);
  i = Std.int(i / FIRST.length);

  while (i > 0) {
    ret += LATER.charAt(i % LATER.length);
    i = Std.int(i / LATER.length);
  }

  return ret;
}

function toValueType(t:Type, ?pos:Position):ValueType {
  return switch Context.followWithAbstracts(t) {
    case TAbstract(a, _): 
      switch a.toString() {
        case "Bool" | "Int": I32;
        case "wasmix.runtime.Float32": F32;
        case "Float": F64;
        case "EnumValue": ExternRef;
        default: error('Unsupported type ${a.toString()}', pos);
      }
    case TInst(c = _.get() => { kind: KTypeParameter(_) }, _): error('Type parameter $c not supported', pos);
    case TInst(BufferViews.getType(_) => Some(kind), _): I64;
    case TDynamic(_) | TEnum(_) | TInst(_): ExternRef;
    default: error('Unsupported type ${t.toString()}', pos);
  }
}

private var curPos:Null<Position>;

function error(message:String, ?pos):Dynamic {
  return Context.error(message, pos ?? currentPos());
}

function currentPos() {
  return curPos ?? Context.currentPos();
}

function at<T>(pos:Position, fn:()->T):T {
  final old = curPos;
  curPos = pos;
  try {
    final ret = fn();
    curPos = old;
    return ret;
  }
  catch (e) {
    curPos = old;
    throw e;
  }
} 