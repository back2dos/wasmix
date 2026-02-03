class Assert {
  static function that(e:Expr) {
    return macro @:pos(Context.currentPos()) @:privateAccess Assert._assert(
      $e, 
      $v{e.toString()}, 
      $v{Context.getLocalModule().split('.').pop()}, 
      $v{Context.getLocalMethod()}
    );
  }

  static public function equal(found:Expr, expected:Expr) {
    return macro @:pos(Context.currentPos()) @:privateAccess Assert._assert(
      Assert._equal($found, $expected), 
      $v{'${found.toString()} is ${expected.toString()}'}, 
      $v{Context.getLocalModule().split('.').pop()}, 
      $v{Context.getLocalMethod()}
    );
  }
}