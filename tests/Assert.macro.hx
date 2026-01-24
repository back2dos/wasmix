class Assert {
  static function that(e:Expr) {
    return macro @:pos(Context.currentPos()) @:privateAccess Assert._assert($e, $v{e.toString()}, $v{Context.getLocalModule().split('.').pop()});
  }
}