package cases;

import js.lib.webassembly.Memory as WasmMemory;
import wasmix.runtime.*;

function main() {
  small();
  large();
}

function large() {
  final memory:Memory = cast new WasmMemory({ initial: 1000 }); // 1000 pages = 64MB
  final allocator = new Allocator(memory, { bucketThreshold: 0 }); // enforced to minimum 0x10000

  // Allocate a large array (> 0x10000 bytes)
  final large1 = allocator.u8(0x20000); // 131072 elements
  Assert.that(large1.byteOffset == 0);
  Assert.that(large1.byteLength == 0x20000);

  // Free it - goes into large free list
  allocator.free(large1);

  // Allocate slightly smaller - waste of 1336 bytes gets chunked into buckets
  // waste = 1336 = 1024 + 256 + 32 + 16 + 8 (binary: 10100111000)
  final large2 = allocator.u8(0x20000 - 1336); // 129736 elements
  Assert.that(large2.byteOffset == 0); // Reuses large block
  Assert.that(large2.byteLength == 0x20000 - 1336);

  // The waste (1336 bytes) is chunked into buckets at these offsets:
  // Starting at cur = 0 + 129736 = 129736
  // i=3: bucket[8] at 129736, cur becomes 129744
  // i=4: bucket[16] at 129744, cur becomes 129760
  // i=5: bucket[32] at 129760, cur becomes 129792
  // i=8: bucket[256] at 129792, cur becomes 130048
  // i=10: bucket[1024] at 130048

  // Consume bucket[8] - need padded size exactly 8
  final b8 = allocator.u8(8);
  Assert.that(b8.byteOffset == 129736);
  Assert.that(b8.byteLength == 8);

  // Consume bucket[16] - need padded size 9-16
  final b16 = allocator.u8(16);
  Assert.that(b16.byteOffset == 129744);
  Assert.that(b16.byteLength == 16);

  // Consume bucket[32] - need padded size 17-32
  final b32 = allocator.u8(32);
  Assert.that(b32.byteOffset == 129760);
  Assert.that(b32.byteLength == 32);

  // Consume bucket[256] - need padded size 129-256
  final b256 = allocator.u8(256);
  Assert.that(b256.byteOffset == 129792);
  Assert.that(b256.byteLength == 256);

  // Consume bucket[1024] - need padded size 513-1024
  final b1024 = allocator.u8(1024);
  Assert.that(b1024.byteOffset == 130048);
  Assert.that(b1024.byteLength == 1024);
}

function small() {
  final memory:Memory = cast new WasmMemory({ initial: 1 }); // 1 page = 64KB
  final allocator = new Allocator(memory);

  // Test basic u8 allocation
  final arr1 = allocator.u8(10);
  Assert.that(arr1.byteOffset == 0);
  Assert.that(arr1.byteLength == 10);

  // Test second allocation is after first (padded to 8 bytes)
  final arr2 = allocator.u8(5);
  Assert.that(arr2.byteOffset == 16); // 10 bytes padded to 16
  Assert.that(arr2.byteLength == 5);

  // Test u16 allocation (2 bytes per element)
  final arr3 = allocator.u16(4);
  Assert.that(arr3.byteOffset == 24); // 16 + 8 (5 padded to 8)
  Assert.that(arr3.byteLength == 8); // 4 elements * 2 bytes

  // Test u32 allocation (4 bytes per element)
  final arr4 = allocator.u32(3);
  Assert.that(arr4.byteOffset == 32); // 24 + 8
  Assert.that(arr4.byteLength == 12); // 3 elements * 4 bytes

  // Test s8 allocation
  final arr5 = allocator.s8(8);
  Assert.that(arr5.byteOffset == 48); // 32 + 16 (12 padded to 16)
  Assert.that(arr5.byteLength == 8);

  // Test free and realloc - after freeing, bucket should be reused
  allocator.free(arr5);
  final arr6 = allocator.s8(8);
  Assert.that(arr6.byteOffset == 48); // Should reuse freed offset
  Assert.that(arr6.byteLength == 8);

  // Test s16 allocation (2 bytes per element)
  final arr7 = allocator.s16(6);
  Assert.that(arr7.byteOffset == 56); // 48 + 8
  Assert.that(arr7.byteLength == 12); // 6 elements * 2 bytes

  // Test s32 allocation (4 bytes per element)
  final arr8 = allocator.s32(5);
  Assert.that(arr8.byteOffset == 72); // 56 + 16 (12 padded to 16)
  Assert.that(arr8.byteLength == 20); // 5 elements * 4 bytes

  // Test freeing and reallocating different sizes
  allocator.free(arr2); // free 8-byte bucket at offset 16
  final arr9 = allocator.u8(7); // needs 8-byte bucket
  Assert.that(arr9.byteOffset == 16); // Should reuse arr2's offset
  Assert.that(arr9.byteLength == 7);

  // Test that allocating larger doesn't reuse smaller bucket
  final arr10 = allocator.u8(20);
  Assert.that(arr10.byteOffset == 96); // 72 + 24 (20 padded to 24)
  Assert.that(arr10.byteLength == 20);

  // Test freeing u16 and reallocating with matching size
  allocator.free(arr3); // free 8-byte bucket at offset 24
  final arr11 = allocator.u16(3); // needs 8-byte bucket (6 bytes padded to 8)
  Assert.that(arr11.byteOffset == 24); // Should reuse arr3's offset
  Assert.that(arr11.byteLength == 6); // 3 elements * 2 bytes

  // Test freeing u32 and reallocating
  allocator.free(arr4); // free 16-byte bucket at offset 32
  final arr12 = allocator.u32(2); // needs 8-byte bucket (8 bytes)
  Assert.that(arr12.byteOffset == 120); // 96 + 24 = 120, new allocation (bucket size mismatch)
  Assert.that(arr12.byteLength == 8); // 2 elements * 4 bytes

  // Verify the 16-byte bucket from arr4 can be reused
  final arr13 = allocator.s32(3); // needs 16-byte bucket (12 bytes padded to 16)
  Assert.that(arr13.byteOffset == 32); // Should reuse arr4's freed offset
  Assert.that(arr13.byteLength == 12); // 3 elements * 4 bytes
}