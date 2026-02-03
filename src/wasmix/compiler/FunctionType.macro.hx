package wasmix.compiler;

class FunctionType {
  public final args:Array<FunctionTypeArg>;
  public final ret:Type;

  function new(args, ret) {
    this.args = args;
    this.ret = ret;
  }

  public function id() {// TODO: this should probably just use WASM types?
    return '(${args.map(a -> a.type.toString()).join(', ')})->${ret.toString()}';
  }

  static public function arrayGet(arr:Type, el:Type) {
    return new FunctionType([{ name: 'arr', type: arr }, { name: 'index', type: Context.getType('Int') }], el);
  }

  static public function arrayLiteral(t:Type, arity:Int) {
    final el = switch t {
      case TInst(_.get() => { pack: [], name: 'Array' }, [t]): t;
      default: throw 'assert';
    }
    return new FunctionType([for (i in 0...arity) { name: 'v${i}', type: el }], t);
  }

  static public function of(t:Type, pos:Position, arity:Null<Int>, ?expected:Type) {
    return switch maybe(t, arity, expected) {
      case Some(v): v;
      case None: Context.error('Expected function type, got $t', pos);
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
        Some(new FunctionType([for (a in args) { name: a.name, type: a.t }], expected ?? ret));
      default:
        None;
    }
  }
}

typedef FunctionTypeArg = { 
  final name:String;
  final type:Type;
};