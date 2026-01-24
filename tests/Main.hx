import examples.*;
import wasmix.runtime.*;

import haxe.Timer.stamp;

function main() {
  wasmix.Compile.module(Example);

  // wasmix.Compile.module(Track).then(x -> {
  //   return;
  //   x.memory.grow(8000);

  //   final length = 40_000_000;

  //   final left = new Float32Array(x.memory.buffer, 0, length);
  //   final right = new Float32Array(x.memory.buffer, left.byteLength, length);

  //   for (i in 0...left.length) {
  //     left[i] = Math.random() * 2 - 1;
  //     right[i] = Math.random() * 2 - 1;
  //   }

  //   final iters = 10;
  //   for (_ in 0...iters) {
  //     x.pan(left, right, 0.0);
  //     Track.pan(left, right, 0.0);
  //   }

  //   for (run in 0...2) {
  //     measure('Wasmix run ${run} (${iters} iters)', () -> {
  //       for (i in 0...iters) x.pan(left, right, 0.0);  // gain = 1.0
  //     });

  //     measure('Track run ${run} (${iters} iters)', () -> {
  //       for (i in 0...iters) Track.pan(left, right, 0.0);  // gain = 1.0
  //     });
  //   }
  // });
}

function measure<T>(what, fn:()->T) {
  final start = stamp();
  fn();
  final end = stamp();
  trace('${what}: ${(end - start) * 1000}ms');
}