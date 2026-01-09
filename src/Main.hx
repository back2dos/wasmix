function main() {
  wasmix.Compile.module(Example).then(Example -> {
    measure('wasm', () -> {
      for (i in 0...5)
        trace('${i}:${Example.fib(i)}');  

      trace(Example.op(11, 2, Add));
      trace(Example.op(11, 2, Sub));
    });
  });
  // measure('js', () -> {
  //   for (i in 0...40)
  //     trace('${i}:${Example.fib(i)}');  
  // });
}

function measure(name:String, fn:() -> Void) {
  final start = haxe.Timer.stamp();
  fn();
  final end = haxe.Timer.stamp();
  trace('${name}: ${end - start}s');
}

class Example {
  static public function add(a:Int, b:Int) {
    return a + b;
  }

  static public function max(a:Int, b:Int) {
    return if (a > b) a else b;
  }

  static public function fib(n:Int) {
    return if (n < 2) 1 else fib(n - 1) + fib(n - 2);
  }

  static public function op(lh:Int, rh:Int, op:Operator) {
    return if (op == Add) lh + rh else lh - rh;
  }

  static public function op2(lh:Int, rh:Int, fn:(Int, Int) -> Int) {
    return fn(lh, rh);
  }

}

enum abstract Operator(Int) {
  var Add;
  var Sub;
  // var Mul = 2;
  // var Div = 3;
  // var Mod = 4;
  // var Eq = 5;
  // var NotEq = 6;
  // var Lt = 7;
  // var Lte = 8;
  // var Gt = 9;
  // var Gte = 10;
}