import js.html.CanvasRenderingContext2D;
import wasmix.runtime.*;

class WaveForm {
  static public function draw(ctx:CanvasRenderingContext2D, channel:Float32Array) {
    var width = ctx.canvas.width,
        center = ctx.canvas.height / 2,
        total = channel.length;

    for (col in 0...width) {
      var start = Math.floor(col * total / width),
          end = Math.ceil((col + 1) * total / width);

      var lo:Float32 = .0,
          hi:Float32 = .0;

      for (x in start...end) {
        var v = channel[x];
        if (v < lo) lo = v;
        else if (v > hi) hi = v;
      }
      
      ctx.fillRect(col, (lo + 1) * center, 1, (hi - lo) * center);
    }
  }
}