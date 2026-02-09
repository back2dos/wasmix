package cases;

import wasmix.Compile;

function main() {
  final arrays = Compile.module(Arrays);

  arrays.literals();
  arrays.constructorNoArgs();
  arrays.pushPop();
  arrays.shiftUnshift();
  arrays.sliceSplice();
  arrays.join();
  arrays.updates();
}

class Arrays {

  static public function literals() {
    final arr = [1, 2, 3];
    Assert.that(arr.length == 3);
    Assert.that(arr[0] == 1);
    Assert.that(arr[1] == 2);
    Assert.that(arr[2] == 3);
  }

  static public function constructorNoArgs() {
    final arr = new Array<Int>();
    Assert.that(arr.length == 0);
  }

  static public function pushPop() {
    final arr = new Array<Int>();
    arr.push(10);
    arr.push(20);
    Assert.equal(arr, [10, 20]);

    Assert.equal(arr.pop(), 20);
    Assert.equal(arr, [10]);
  }

  static public function shiftUnshift() {
    final arr = [1, 2, 3];
    

    Assert.equal(arr.shift(), 1);
    Assert.equal(arr, [2, 3]);

    arr.unshift(0);
    Assert.equal(arr, [0, 2, 3]);
  }

  static public function sliceSplice() {
    final arr = [1, 2, 3, 4, 5];
    
    Assert.equal(arr.slice(1, 3), [2, 3]);
    Assert.equal(arr.splice(1, 2), [2, 3]);
    Assert.equal(arr, [1, 4, 5]);
  }

  static public function join() {
    final arr = ["a", "b", "c"];
    Assert.that(arr.join(",") == "a,b,c");
    Assert.that(arr.join("") == "abc");
  }

  static public function updates() {
    final arr = [1, 2, 3];
    arr[0] = 10;
    arr[1] *= 10;
    arr[2] += 100;
    Assert.equal(arr, [10, 20, 103]);
  }
}
