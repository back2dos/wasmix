package examples;

import wasmix.runtime.*;
import haxe.ds.Option;

class Test {
  static public function hi() {
    console.log('hello, world!');
  }
}

class Example {
  static public function casts():Float {
    final v:Float32 = 1;
    return v;
  }
  static public function double(e:Option<Int>) {
    return switch e {
      case Some(x): Some(x * 2);
      case None: None;
    }
  }

  static public function length(u:Int16Array) {
    return u.length;
  }

  static public function sum(u:Int16Array) {
    var sum = 0;
    for (k in u) sum += k;
    return sum;
  }

  static public function roundtrip(u:Int16Array) {
    return u;
  }
  
  static public function inc(u:Int16Array, delta:Int) {
    for (i in 0...u.length) u[i] += delta;
  }
  // static public function enums(e:Option<Int>) {
  //   return switch e {
  //     case Some(x): x;
  //     case None: 0;
  //   }
  // }

  // static public function fib(n:Int) {
  //   return if (n < 2) 1 else fib(n - 1) + fib(n - 2);
  // }

  // static public function op(lh:Int, rh:Int, op:Operator) {
  //   return switch op {
  //     case Add: lh + rh;
  //     case Sub: lh - rh;
  //   }
    
    // if (op == Add) lh + rh else lh - rh;
  // }

  // static public function op2(lh:Int, rh:Int, fn:(Int, Int) -> Int) {
  //   return fn(lh, rh);
  // }
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