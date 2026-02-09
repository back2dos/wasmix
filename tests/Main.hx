import examples.*;
import wasmix.runtime.*;
import haxe.ds.Option;

import haxe.Timer.stamp;

function main() {

  final waveForm = wasmix.Compile.module(WaveForm);
  // final example = wasmix.Compile.module(Example, { validate: true });

  // trace(example.test2('nil'));
  // // // trace(example.fib(10));

  // // trace(example.test(new Allocator(example.memory)));
  // // trace(example.test2('nil'));

  // final allocator = new Allocator(waveForm.memory);
  // final audio = allocator.f32(44100 * 200); // 200 seconds of audio

  // for (i in 0...audio.length) audio[i] = Math.random() * 2 - 1;

  // final ctx:js.html.CanvasRenderingContext2D = cast { fillRect: function () {}, canvas: { width: 100, height: 100 }};
  
  // measure('wasmix', () -> {
  //   for (i in 0...100) waveForm.draw(ctx, audio);
  // });

  // measure('    js', () -> {
  //   for (i in 0...100) WaveForm.draw(ctx, audio);
  // });

  // return;

  // final options = [Some(1), None];

  // measure('wasmix', () -> {
  //   for (i in 0...1_000_000)
  //     example.double(options[i % 2]);
  // });

  // measure('    js', () -> {
  //   for (i in 0...1_000_000)
  //     Example.double(options[i % 2]);
  // });
  
  final track = wasmix.Compile.module(Track);

  track.memory.grow(8000);

  final length = 40_000_000;

  final left = new Float32Array(track.memory.buffer, 0, length);
  final right = new Float32Array(track.memory.buffer, left.byteLength, length);

  for (i in 0...left.length) {
    left[i] = Math.random() * 2 - 1;
    right[i] = Math.random() * 2 - 1;
  }

  final iters = 10;
  for (_ in 0...iters) {
    track.pan(left, right, 0.0);
    Track.pan(left, right, 0.0);
  }

  for (run in 0...2) {
    measure('Wasmix run ${run} (${iters} iters)', () -> {
      for (i in 0...iters) track.pan(left, right, 0.0);  // gain = 1.0
    });

    measure('Track run ${run} (${iters} iters)', () -> {
      for (i in 0...iters) Track.pan(left, right, 0.0);  // gain = 1.0
    });
  }
}

function measure<T>(what, fn:()->T) {
  final start = stamp();
  fn();
  final end = stamp();
  trace('${what}: ${(end - start) * 1000}ms');
}