package wasmix.compiler;

class FunctionType {
  public final args:Array<FunctionTypeArg>;
  public final ret:Type;

  public function new(args, ret) {
    this.args = args;
    this.ret = ret;
  }

  public function id() {// TODO: this should probably just use WASM types?
    return '(${args.map(a -> a.type.toString()).join(', ')})->${ret.toString()}';
  }

  static public function of(t, arity, ?expected) {
    return switch maybe(t, arity, expected) {
      case Some(v): v;
      case None: error('Expected function type, got $t');
    }
  }

  static public function maybe(t:Type, arity:Null<Int>, ?expected:Type) {
    return switch Context.follow(t) {
      case TFun(args, ret):

        arity ??= args.length;

        switch args[args.length - 1] {
          case null:
          case a = { t: TAbstract(_.toString() => 'haxe.Rest', [t]) }:
            args = args.slice(0, -1);
            for (i in 0...arity - args.length) 
              args.push({ name: '${a.name}_${i}', t: t, opt: false });
          default:
        }
        Some(new FunctionType([for (a in args) { name: a.name, type: a.t, valueType: toValueType(a.t) }], expected ?? ret));
      default:
        None;
    }
  }
}

typedef FunctionTypeArg = { 
  final name:String;
  final type:Type;
  final valueType:ValueType;
};