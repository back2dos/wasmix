package wasmix.runtime;

import haxe.ds.ReadOnlyArray;

enum abstract BufferViewType(String) {
  var Float32;
  var Float64;
  
  var Uint8;
  var Uint16;
  var Uint32;

  var Int8;
  var Int16;
  var Int32;

  static final GROUPED = [[Int8, Uint8], [Int16, Uint16], [Int32, Uint32, Float32], [Float64]];
  static public final ALL:ReadOnlyArray<BufferViewType> = [for (g in GROUPED) for (t in g) t];
  static final ALIGNMENTS = [for (i => g in GROUPED) for (t in g) t => i];
  static final WIDTHS = [for (i => g in GROUPED) for (t in g) t => 1 << i];

  public var width(get, never):Int;
  inline function get_width() return (WIDTHS[abstract]:Int);

  public var alignment(get, never):Int;
  inline function get_alignment() return (ALIGNMENTS[abstract]:Int);
}