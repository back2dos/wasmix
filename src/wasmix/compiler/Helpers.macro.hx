package wasmix.compiler;

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