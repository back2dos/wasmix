import js.lib.*;

import haxe.Timer.stamp;

function main() {
  wasmix.Compile.module(Example).then(x -> {
    x.memory.grow(100);
    final arr = new Int16Array(x.memory.buffer, 0, 1000000);
    for (i in 0...arr.length) arr[i] = 1;
    
    trace(arr.length);
    
    final wasm = x.memory.toWASM(arr);

    x.inc(cast wasm, 10);

    trace(arr[Std.random(arr.length)]);
    
    // measure('WASM', () -> {
    //   var sum = 0; 
    //   for (i in 0...1000) sum = x.sum(cast wasm);
    //   trace(sum);
    // });
    
    // measure('JS', () -> {
    //   var sum = 0; 
    //   for (i in 0...1000) sum = Example.sum(arr);
    //   trace(sum);
    // });
  });
}

function measure(what, fn) {
  final start = stamp();
  fn();
  final end = stamp();
  trace('${what}: ${end - start}ms');
}