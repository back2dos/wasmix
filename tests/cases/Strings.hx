package cases;

import wasmix.Compile;

function main() {
  final strings = Compile.module(Strings);

  strings.comparisons();
  strings.concatenations("foo", "bar");
}

class Strings {

  // Comparisons - all tests in one function
  static public function comparisons() {
    Assert.that("abc" == "abc");
    Assert.that(!("abc" == "def"));

    Assert.that("abc" != "def");
    Assert.that(!("abc" != "abc"));

    Assert.that("abc" < "def");
    Assert.that(!("def" < "abc"));

    Assert.that("def" > "abc");
    Assert.that(!("abc" > "def"));

    Assert.that("abc" <= "abc");
    Assert.that("abc" <= "def");

    Assert.that("abc" >= "abc");
    Assert.that("def" >= "abc");
  }

  static public function concatenations(foo:String, bar:String) {
    Assert.that("hello" + foo + "world" == "hellofooworld");
    Assert.that('hello${bar}world' == 'hellobarworld');
  }
}
