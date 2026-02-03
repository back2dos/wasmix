package wasmix.runtime;

class Allocator {
  
  final memory:Memory;

  var heapSize = 0;

  final buckets = new Map<Int, Array<Int>>();// TODO: this could probably just be an array

  final large = new Array<{ final size:Int; final offset:Int; }>();// descending order

  final bucketThreshold:Int;

  public function new(memory, ?options:{ ?bucketThreshold:Int }) {
    this.memory = memory;
    this.bucketThreshold = switch options?.bucketThreshold {
      case null: 0x1000000;
      case v: if (v < 0x10000) 0x10000 else nextPowerOfTwo(v);
    }
  }

  public function s8(length) return {
    final offset = alloc(0, length);
    new Int8Array(memory.buffer, offset, length);
  }
  public function s16(length) return {
    final offset = alloc(1, length);
    new Int16Array(memory.buffer, offset, length);
  }
  public function s32(length) return {
    final offset = alloc(2, length);
    new Int32Array(memory.buffer, offset, length);
  }
  public function u8(length) return {
    final offset = alloc(0, length);
    new Uint8Array(memory.buffer, offset, length);
  }
  public function u16(length) return {
    final offset = alloc(1, length);
    new Uint16Array(memory.buffer, offset, length);
  }
  public function u32(length) return {
    final offset = alloc(2, length);
    new Uint32Array(memory.buffer, offset, length);
  }
  public function f32(length) return {
    final offset = alloc(2, length);
    new Float32Array(memory.buffer, offset, length);
  }
  public function f64(length) return {
    final offset = alloc(3, length);
    new Float64Array(memory.buffer, offset, length);
  }

  overload public extern inline function free(s8:Int8Array) _free(0, s8.byteOffset, s8.length);
  overload public extern inline function free(s16:Int16Array) _free(1, s16.byteOffset, s16.length);
  overload public extern inline function free(s32:Int32Array) _free(2, s32.byteOffset, s32.length);
  overload public extern inline function free(u8:Uint8Array) _free(0, u8.byteOffset, u8.length);
  overload public extern inline function free(u16:Uint16Array) _free(1, u16.byteOffset, u16.length);
  overload public extern inline function free(u32:Uint32Array) _free(2, u32.byteOffset, u32.length);
  overload public extern inline function free(f32:Float32Array) _free(2, f32.byteOffset, f32.length);
  overload public extern inline function free(f64:Float64Array) _free(3, f64.byteOffset, f64.length);

  /**
    Should allocate space for a typed array of the given length and alignment.
    The width of every element is 1 << align and there are length elements. 
    The `align` can only be 0, 1, 2 or 3.
    Returns the initial offset of the allocated space, always aligned to 8 bytes.
  **/
  function alloc(align:Int, length:Int):Int {
    final size = sizeOf(align, length);
    return switch bucketSize(size) {
      case -1:
        switch findLargeBlock(size) {
          case -1: 
            grow(size);
          case large.splice(_, 1)[0] => { offset: offset, size: s }: 
            final waste = s - size;
            if (waste > bucketThreshold)
              freeLarge(offset + size, waste);
            else {
              var cur = offset + size;

              for (i in 0...31) {
                final size = 1 << i;
                if (size > waste) break;
                if (waste & size != 0) {
                  (buckets[size] ??= []).push(cur);
                  cur += size;
                }
              }
            }
            offset;
        }
      case b:
        (buckets[b] ??= []).pop() ?? grow(size);
    }
  }

  function grow(by:Int) {
    final ret = heapSize,
          used = heapSize += by,
          available = memory.buffer.byteLength;

    if (used > available) 
      memory.grow(((used - available) >> 16) + 1);

    return ret;
  }

  static inline function pad(size:Int) {
    return switch size % 8 {
      case 0: size;
      case v: size + 8 - v;
    }
  }

  /**
    Can free space allocated by allocate.
  **/
  function _free(align:Int, offset:Int, length:Int) {
    final size = sizeOf(align, length);
    switch bucketSize(size) {
      case -1: freeLarge(offset, size);
      case b: (buckets[b] ??= []).push(offset);
    }
  }

  function freeLarge(offset:Int, size:Int) {
    large.insert(findLargeInsertPos(size), { size: size, offset: offset });
  }

  inline function findLargeBlock(size:Int):Int {
    if (large.length == 0 || large[0].size < size) return -1;
    
    var lo = 0, 
        hi = large.length - 1;
    while (lo < hi) {
      final mid = lo + ((hi - lo + 1) >> 1);  // bias right
      if (large[mid].size >= size) lo = mid;
      else hi = mid - 1;
    }
    return lo;
  }

  inline function findLargeInsertPos(size:Int):Int {
    var lo = 0, 
        hi = large.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (large[mid].size > size) lo = mid + 1;
      else hi = mid;
    }
    return lo;
  }

  static inline function sizeOf(align:Int, length:Int):Int {
    return pad(length * (1 << align));
  }

  function bucketSize(n:Int) {
    return if (n > bucketThreshold) -1 else nextPowerOfTwo(n);
  }

  static function nextPowerOfTwo(n:Int):Int {
    var ret = n;
    ret--;
    ret |= ret >> 1;
    ret |= ret >> 2;
    ret |= ret >> 4;
    ret |= ret >> 8;
    ret |= ret >> 16;
    return ret + 1;
  }

}