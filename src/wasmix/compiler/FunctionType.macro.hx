package wasmix.compiler;

class FunctionType {
  public final args:Array<{ final name:String; final type:Type; }>;
  public final ret:Type;

  public function new(args, ret) {
    this.args = args;
    this.ret = ret;
  }

  public function id() {// TODO: this should probably just use WASM types
    return '(${args.map(a -> a.type.toString()).join(', ')})->${ret.toString()}';
  }

  static public function of(t:Type, pos:Position) {
    return switch Context.follow(t) {
      case TFun(args, ret):
        new FunctionType([for (a in args) { name: a.name, type: a.t }], ret);
      case v:
        Context.error('Expected function type, got $t', pos);
    }
  }
}