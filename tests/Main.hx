import haxe.Timer.stamp;
#if nodejs
import js.Node.console;
#else
import js.Browser.console;
#end

function main() {
  wasmix.Compile.module(Example).then(x -> {
    var o = [haxe.ds.Option.None, haxe.ds.Option.Some(123)];
    var res = o[0];
    measure('  JS', () -> {
      for (i in 0...10_000_000) res = Example.double(o[i % 2]);
    });

    measure('WASM', () -> {
      for (i in 0...10_000_000) res = x.double(o[i % 2]);
    });

    trace(res);
  });
}

function measure(what, fn) {
  final start = stamp();
  fn();
  final end = stamp();
  trace('${what}: ${end - start}ms');
}