package wasmix.wasm;

import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Output;
import wasmix.wasm.Data;

/**
 * Writes a WASM module in binary format to a haxe.io.Output.
 * 
 * Usage:
 * ```haxe
 * var module:Module = { ... };
 * var output = new BytesOutput();
 * new Writer(output).write(module);
 * var bytes = output.getBytes();
 * ```
 */
class Writer {
  static inline var WASM_MAGIC:Int = 0x6D736100; // "\0asm" in little-endian
  static inline var WASM_VERSION:Int = 1;

  // Section IDs
  static inline var SECTION_TYPE:Int = 1;
  static inline var SECTION_IMPORT:Int = 2;
  static inline var SECTION_FUNCTION:Int = 3;
  static inline var SECTION_TABLE:Int = 4;
  static inline var SECTION_MEMORY:Int = 5;
  static inline var SECTION_GLOBAL:Int = 6;
  static inline var SECTION_EXPORT:Int = 7;
  static inline var SECTION_START:Int = 8;
  static inline var SECTION_ELEMENT:Int = 9;
  static inline var SECTION_CODE:Int = 10;
  static inline var SECTION_DATA:Int = 11;

  var output:Output;

  static public function toBytes(module:Module):Bytes {
    final output = new BytesOutput();
    final writer = new Writer(output);
    writer.write(module);
    return output.getBytes();
  }

  public function new(output:Output) {
    this.output = output;
  }

  public function write(module:Module):Void {
    // Write magic number and version
    writeUInt32(WASM_MAGIC);
    writeUInt32(WASM_VERSION);

    // Write sections in order
    writeTypeSection(module.types);
    writeImportSection(module.imports);
    writeFunctionSection(module.functions);
    writeTableSection(module.tables);
    writeMemorySection(module.memories);
    writeGlobalSection(module.globals);
    writeExportSection(module.exports);
    writeStartSection(module.start);
    writeElementSection(module.elements);
    writeCodeSection(module.functions);
    writeDataSection(module.data);
  }

  // ========================================================================
  // Primitive Writers
  // ========================================================================

  inline function writeByte(b:Int):Void {
    output.writeByte(b);
  }

  function writeUInt32(v:Int):Void {
    output.writeByte(v & 0xFF);
    output.writeByte((v >> 8) & 0xFF);
    output.writeByte((v >> 16) & 0xFF);
    output.writeByte((v >> 24) & 0xFF);
  }

  /**
   * Write an unsigned LEB128 encoded integer.
   */
  function writeULEB128(value:Int):Void {
    do {
      var b = value & 0x7F;
      value >>>= 7;
      if (value != 0) {
        b |= 0x80;
      }
      writeByte(b);
    } while (value != 0);
  }

  /**
   * Write a signed LEB128 encoded integer.
   */
  function writeSLEB128(value:Int):Void {
    var more = true;
    while (more) {
      var b = value & 0x7F;
      value >>= 7;
      // Check if more bytes are needed
      if ((value == 0 && (b & 0x40) == 0) || (value == -1 && (b & 0x40) != 0)) {
        more = false;
      } else {
        b |= 0x80;
      }
      writeByte(b);
    }
  }

  /**
   * Write a signed LEB128 encoded 64-bit integer.
   */
  function writeSLEB128_64(value:Int64):Void {
    var more = true;
    while (more) {
      var b = Int64.toInt(value & Int64.make(0, 0x7F));
      value = value >> 7;
      // Check if more bytes are needed
      var signBit = (b & 0x40) != 0;
      if ((value == Int64.make(0, 0) && !signBit) || (value == Int64.make(-1, -1) && signBit)) {
        more = false;
      } else {
        b |= 0x80;
      }
      writeByte(b);
    }
  }

  /**
   * Write a vector with length prefix.
   */
  function writeVector<T>(items:Array<T>, writeItem:(T) -> Void):Void {
    if (items == null) {
      writeULEB128(0);
      return;
    }
    writeULEB128(items.length);
    for (item in items) {
      writeItem(item);
    }
  }

  /**
   * Write a UTF-8 encoded string with length prefix.
   */
  function writeName(name:String):Void {
    var bytes = Bytes.ofString(name);
    writeULEB128(bytes.length);
    output.write(bytes);
  }

  /**
   * Write a section: section id, size, content.
   */
  function writeSection(sectionId:Int, writeContent:() -> Void):Void {
    var buffer = new BytesOutput();
    var savedOutput = output;
    output = buffer;
    writeContent();
    output = savedOutput;

    var bytes = buffer.getBytes();
    writeByte(sectionId);
    writeULEB128(bytes.length);
    output.write(bytes);
  }

  // ========================================================================
  // Type Writers
  // ========================================================================

  function writeValueType(vt:ValueType):Void {
    writeByte(cast vt);
  }

  function writeLimits(limits:Limits):Void {
    if (limits.max != null) {
      writeByte(0x01);
      writeULEB128(limits.min);
      writeULEB128(limits.max);
    } else {
      writeByte(0x00);
      writeULEB128(limits.min);
    }
  }

  function writeTableType(tableType:TableType):Void {
    writeValueType(tableType.elementType);
    writeLimits(tableType.limits);
  }

  function writeMemoryType(memType:MemoryType):Void {
    writeLimits(memType.limits);
  }

  function writeGlobalType(globalType:GlobalType):Void {
    writeValueType(globalType.valueType);
    writeByte(globalType.mutable ? 0x01 : 0x00);
  }

  function writeFunctionType(funcType:FunctionType):Void {
    writeByte(0x60); // Function type marker
    writeVector(funcType.params, writeValueType);
    writeVector(funcType.results, writeValueType);
  }

  function writeBlockType(blockType:BlockType):Void {
    switch (blockType) {
      case Empty:
        writeByte(0x40);
      case ValueType(vt):
        writeValueType(vt);
      case TypeIndex(index):
        writeSLEB128(index);
    }
  }

  // ========================================================================
  // Section Writers
  // ========================================================================

  function writeTypeSection(types:Array<FunctionType>):Void {
    if (types == null || types.length == 0) return;
    writeSection(SECTION_TYPE, () -> {
      writeVector(types, writeFunctionType);
    });
  }

  function writeImportSection(imports:Array<Import>):Void {
    if (imports == null || imports.length == 0) return;
    writeSection(SECTION_IMPORT, () -> {
      writeVector(imports, writeImport);
    });
  }

  function writeImport(imp:Import):Void {
    writeName(imp.module);
    writeName(imp.name);
    switch (imp.kind) {
      case ImportFunction(typeIndex):
        writeByte(0x00);
        writeULEB128(typeIndex);
      case ImportTable(tableType):
        writeByte(0x01);
        writeTableType(tableType);
      case ImportMemory(memoryType):
        writeByte(0x02);
        writeMemoryType(memoryType);
      case ImportGlobal(globalType):
        writeByte(0x03);
        writeGlobalType(globalType);
    }
  }

  function writeFunctionSection(functions:Array<Function>):Void {
    if (functions == null || functions.length == 0) return;
    writeSection(SECTION_FUNCTION, () -> {
      writeULEB128(functions.length);
      for (func in functions) {
        writeULEB128(func.typeIndex);
      }
    });
  }

  function writeTableSection(tables:Array<TableType>):Void {
    if (tables == null || tables.length == 0) return;
    writeSection(SECTION_TABLE, () -> {
      writeVector(tables, writeTableType);
    });
  }

  function writeMemorySection(memories:Array<MemoryType>):Void {
    if (memories == null || memories.length == 0) return;
    writeSection(SECTION_MEMORY, () -> {
      writeVector(memories, writeMemoryType);
    });
  }

  function writeGlobalSection(globals:Array<Global>):Void {
    if (globals == null || globals.length == 0) return;
    writeSection(SECTION_GLOBAL, () -> {
      writeVector(globals, writeGlobal);
    });
  }

  function writeGlobal(global:Global):Void {
    writeGlobalType(global.type);
    writeExpression(global.init);
  }

  function writeExportSection(exports:Array<Export>):Void {
    if (exports == null || exports.length == 0) return;
    writeSection(SECTION_EXPORT, () -> {
      writeVector(exports, writeExport);
    });
  }

  function writeExport(exp:Export):Void {
    writeName(exp.name);
    switch (exp.kind) {
      case ExportFunction(functionIndex):
        writeByte(0x00);
        writeULEB128(functionIndex);
      case ExportTable(tableIndex):
        writeByte(0x01);
        writeULEB128(tableIndex);
      case ExportMemory(memoryIndex):
        writeByte(0x02);
        writeULEB128(memoryIndex);
      case ExportGlobal(globalIndex):
        writeByte(0x03);
        writeULEB128(globalIndex);
    }
  }

  function writeStartSection(startFunctionIndex:Null<Int>):Void {
    if (startFunctionIndex == null) return;
    writeSection(SECTION_START, () -> {
      writeULEB128(startFunctionIndex);
    });
  }

  function writeElementSection(elements:Array<Element>):Void {
    if (elements == null || elements.length == 0) return;
    writeSection(SECTION_ELEMENT, () -> {
      writeVector(elements, writeElement);
    });
  }

  function writeElement(elem:Element):Void {
    // Simple active element segment (type 0)
    writeByte(0x00);
    writeExpression(elem.offset);
    writeVector(elem.init, writeULEB128);
  }

  function writeCodeSection(functions:Array<Function>):Void {
    if (functions == null || functions.length == 0) return;
    writeSection(SECTION_CODE, () -> {
      writeULEB128(functions.length);
      for (func in functions) {
        writeCode(func);
      }
    });
  }

  function writeCode(func:Function):Void {
    // Write to a temporary buffer to get the size
    var buffer = new BytesOutput();
    var savedOutput = output;
    output = buffer;

    // Write locals (compressed by type)
    writeLocals(func.locals);
    // Write body
    writeExpression(func.body);

    output = savedOutput;
    var bytes = buffer.getBytes();
    writeULEB128(bytes.length);
    output.write(bytes);
  }

  function writeLocals(locals:Array<ValueType>):Void {
    if (locals == null || locals.length == 0) {
      writeULEB128(0);
      return;
    }

    // Compress locals by grouping consecutive types
    var groups:Array<{count:Int, type:ValueType}> = [];
    var i = 0;
    while (i < locals.length) {
      var currentType = locals[i];
      var count = 1;
      while (i + count < locals.length && locals[i + count] == currentType) {
        count++;
      }
      groups.push({count: count, type: currentType});
      i += count;
    }

    writeULEB128(groups.length);
    for (group in groups) {
      writeULEB128(group.count);
      writeValueType(group.type);
    }
  }

  function writeDataSection(data:Array<DataSegment>):Void {
    if (data == null || data.length == 0) return;
    writeSection(SECTION_DATA, () -> {
      writeVector(data, writeDataSegment);
    });
  }

  function writeDataSegment(segment:DataSegment):Void {
    // Active data segment with memory index 0
    if (segment.memoryIndex == 0) {
      writeByte(0x00);
    } else {
      writeByte(0x02);
      writeULEB128(segment.memoryIndex);
    }
    writeExpression(segment.offset);
    writeULEB128(segment.init.length);
    for (b in segment.init) {
      writeByte(b);
    }
  }

  // ========================================================================
  // Expression/Instruction Writers
  // ========================================================================

  function writeExpression(expr:Expression):Void {
    if (expr != null) {
      for (instr in expr) {
        writeInstruction(instr);
      }
    }
    writeByte(0x0B); // end
  }

  function writeMemArg(offset:Int, align:Int):Void {
    writeULEB128(align);
    writeULEB128(offset);
  }

  function writeInstruction(instr:Instruction):Void {
    switch (instr) {
      // Control flow
      case Unreachable:
        writeByte(0x00);
      case Nop:
        writeByte(0x01);
      case Block(blockType, body):
        writeByte(0x02);
        writeBlockType(blockType);
        if (body != null) {
          for (i in body) writeInstruction(i);
        }
        writeByte(0x0B);
      case Loop(blockType, body):
        writeByte(0x03);
        writeBlockType(blockType);
        if (body != null) {
          for (i in body) writeInstruction(i);
        }
        writeByte(0x0B);
      case If(blockType, thenBody, elseBody):
        writeByte(0x04);
        writeBlockType(blockType);
        if (thenBody != null) {
          for (i in thenBody) writeInstruction(i);
        }
        if (elseBody != null) {
          writeByte(0x05);
          for (i in elseBody) writeInstruction(i);
        }
        writeByte(0x0B);
      case Br(labelIndex):
        writeByte(0x0C);
        writeULEB128(labelIndex);
      case BrIf(labelIndex):
        writeByte(0x0D);
        writeULEB128(labelIndex);
      case BrTable(labelIndices, defaultLabel):
        writeByte(0x0E);
        writeVector(labelIndices, writeULEB128);
        writeULEB128(defaultLabel);
      case Return:
        writeByte(0x0F);
      case Call(functionIndex):
        writeByte(0x10);
        writeULEB128(functionIndex);
      case CallIndirect(typeIndex):
        writeByte(0x11);
        writeULEB128(typeIndex);
        writeByte(0x00); // table index

      // Parametric
      case Drop:
        writeByte(0x1A);
      case Select:
        writeByte(0x1B);
      case SelectTyped(types):
        writeByte(0x1C);
        writeVector(types, writeValueType);

      // Variable access
      case LocalGet(localIndex):
        writeByte(0x20);
        writeULEB128(localIndex);
      case LocalSet(localIndex):
        writeByte(0x21);
        writeULEB128(localIndex);
      case LocalTee(localIndex):
        writeByte(0x22);
        writeULEB128(localIndex);
      case GlobalGet(globalIndex):
        writeByte(0x23);
        writeULEB128(globalIndex);
      case GlobalSet(globalIndex):
        writeByte(0x24);
        writeULEB128(globalIndex);

      // Memory operations
      case I32Load(offset, align):
        writeByte(0x28);
        writeMemArg(offset, align);
      case I64Load(offset, align):
        writeByte(0x29);
        writeMemArg(offset, align);
      case F32Load(offset, align):
        writeByte(0x2A);
        writeMemArg(offset, align);
      case F64Load(offset, align):
        writeByte(0x2B);
        writeMemArg(offset, align);
      case I32Load8S(offset, align):
        writeByte(0x2C);
        writeMemArg(offset, align);
      case I32Load8U(offset, align):
        writeByte(0x2D);
        writeMemArg(offset, align);
      case I32Load16S(offset, align):
        writeByte(0x2E);
        writeMemArg(offset, align);
      case I32Load16U(offset, align):
        writeByte(0x2F);
        writeMemArg(offset, align);
      case I64Load8S(offset, align):
        writeByte(0x30);
        writeMemArg(offset, align);
      case I64Load8U(offset, align):
        writeByte(0x31);
        writeMemArg(offset, align);
      case I64Load16S(offset, align):
        writeByte(0x32);
        writeMemArg(offset, align);
      case I64Load16U(offset, align):
        writeByte(0x33);
        writeMemArg(offset, align);
      case I64Load32S(offset, align):
        writeByte(0x34);
        writeMemArg(offset, align);
      case I64Load32U(offset, align):
        writeByte(0x35);
        writeMemArg(offset, align);
      case I32Store(offset, align):
        writeByte(0x36);
        writeMemArg(offset, align);
      case I64Store(offset, align):
        writeByte(0x37);
        writeMemArg(offset, align);
      case F32Store(offset, align):
        writeByte(0x38);
        writeMemArg(offset, align);
      case F64Store(offset, align):
        writeByte(0x39);
        writeMemArg(offset, align);
      case I32Store8(offset, align):
        writeByte(0x3A);
        writeMemArg(offset, align);
      case I32Store16(offset, align):
        writeByte(0x3B);
        writeMemArg(offset, align);
      case I64Store8(offset, align):
        writeByte(0x3C);
        writeMemArg(offset, align);
      case I64Store16(offset, align):
        writeByte(0x3D);
        writeMemArg(offset, align);
      case I64Store32(offset, align):
        writeByte(0x3E);
        writeMemArg(offset, align);
      case MemorySize(memoryIndex):
        writeByte(0x3F);
        writeByte(memoryIndex);
      case MemoryGrow(memoryIndex):
        writeByte(0x40);
        writeByte(memoryIndex);
      case MemoryInit(dataIndex, memoryIndex):
        writeByte(0xFC);
        writeULEB128(8);
        writeULEB128(dataIndex);
        writeByte(memoryIndex);
      case DataDrop(dataIndex):
        writeByte(0xFC);
        writeULEB128(9);
        writeULEB128(dataIndex);
      case MemoryCopy(destMemIndex, srcMemIndex):
        writeByte(0xFC);
        writeULEB128(10);
        writeByte(destMemIndex);
        writeByte(srcMemIndex);
      case MemoryFill(memoryIndex):
        writeByte(0xFC);
        writeULEB128(11);
        writeByte(memoryIndex);

      // Numeric constants
      case I32Const(value):
        writeByte(0x41);
        writeSLEB128(value);
      case I64Const(value):
        writeByte(0x42);
        writeSLEB128_64(value);
      case F32Const(value):
        writeByte(0x43);
        writeF32(value);
      case F64Const(value):
        writeByte(0x44);
        writeF64(value);

      // I32 operations
      case I32Clz:
        writeByte(0x67);
      case I32Ctz:
        writeByte(0x68);
      case I32Popcnt:
        writeByte(0x69);
      case I32Add:
        writeByte(0x6A);
      case I32Sub:
        writeByte(0x6B);
      case I32Mul:
        writeByte(0x6C);
      case I32DivS:
        writeByte(0x6D);
      case I32DivU:
        writeByte(0x6E);
      case I32RemS:
        writeByte(0x6F);
      case I32RemU:
        writeByte(0x70);
      case I32And:
        writeByte(0x71);
      case I32Or:
        writeByte(0x72);
      case I32Xor:
        writeByte(0x73);
      case I32Shl:
        writeByte(0x74);
      case I32ShrS:
        writeByte(0x75);
      case I32ShrU:
        writeByte(0x76);
      case I32Rotl:
        writeByte(0x77);
      case I32Rotr:
        writeByte(0x78);

      // I64 operations
      case I64Clz:
        writeByte(0x79);
      case I64Ctz:
        writeByte(0x7A);
      case I64Popcnt:
        writeByte(0x7B);
      case I64Add:
        writeByte(0x7C);
      case I64Sub:
        writeByte(0x7D);
      case I64Mul:
        writeByte(0x7E);
      case I64DivS:
        writeByte(0x7F);
      case I64DivU:
        writeByte(0x80);
      case I64RemS:
        writeByte(0x81);
      case I64RemU:
        writeByte(0x82);
      case I64And:
        writeByte(0x83);
      case I64Or:
        writeByte(0x84);
      case I64Xor:
        writeByte(0x85);
      case I64Shl:
        writeByte(0x86);
      case I64ShrS:
        writeByte(0x87);
      case I64ShrU:
        writeByte(0x88);
      case I64Rotl:
        writeByte(0x89);
      case I64Rotr:
        writeByte(0x8A);

      // F32 operations
      case F32Abs:
        writeByte(0x8B);
      case F32Neg:
        writeByte(0x8C);
      case F32Ceil:
        writeByte(0x8D);
      case F32Floor:
        writeByte(0x8E);
      case F32Trunc:
        writeByte(0x8F);
      case F32Nearest:
        writeByte(0x90);
      case F32Sqrt:
        writeByte(0x91);
      case F32Add:
        writeByte(0x92);
      case F32Sub:
        writeByte(0x93);
      case F32Mul:
        writeByte(0x94);
      case F32Div:
        writeByte(0x95);
      case F32Min:
        writeByte(0x96);
      case F32Max:
        writeByte(0x97);
      case F32Copysign:
        writeByte(0x98);

      // F64 operations
      case F64Abs:
        writeByte(0x99);
      case F64Neg:
        writeByte(0x9A);
      case F64Ceil:
        writeByte(0x9B);
      case F64Floor:
        writeByte(0x9C);
      case F64Trunc:
        writeByte(0x9D);
      case F64Nearest:
        writeByte(0x9E);
      case F64Sqrt:
        writeByte(0x9F);
      case F64Add:
        writeByte(0xA0);
      case F64Sub:
        writeByte(0xA1);
      case F64Mul:
        writeByte(0xA2);
      case F64Div:
        writeByte(0xA3);
      case F64Min:
        writeByte(0xA4);
      case F64Max:
        writeByte(0xA5);
      case F64Copysign:
        writeByte(0xA6);

      // Conversions
      case I32WrapI64:
        writeByte(0xA7);
      case I32TruncF32S:
        writeByte(0xA8);
      case I32TruncF32U:
        writeByte(0xA9);
      case I32TruncF64S:
        writeByte(0xAA);
      case I32TruncF64U:
        writeByte(0xAB);
      case I64ExtendI32S:
        writeByte(0xAC);
      case I64ExtendI32U:
        writeByte(0xAD);
      case I64TruncF32S:
        writeByte(0xAE);
      case I64TruncF32U:
        writeByte(0xAF);
      case I64TruncF64S:
        writeByte(0xB0);
      case I64TruncF64U:
        writeByte(0xB1);
      case F32ConvertI32S:
        writeByte(0xB2);
      case F32ConvertI32U:
        writeByte(0xB3);
      case F32ConvertI64S:
        writeByte(0xB4);
      case F32ConvertI64U:
        writeByte(0xB5);
      case F32DemoteF64:
        writeByte(0xB6);
      case F64ConvertI32S:
        writeByte(0xB7);
      case F64ConvertI32U:
        writeByte(0xB8);
      case F64ConvertI64S:
        writeByte(0xB9);
      case F64ConvertI64U:
        writeByte(0xBA);
      case F64PromoteF32:
        writeByte(0xBB);
      case I32ReinterpretF32:
        writeByte(0xBC);
      case I64ReinterpretF64:
        writeByte(0xBD);
      case F32ReinterpretI32:
        writeByte(0xBE);
      case F64ReinterpretI64:
        writeByte(0xBF);

      // I32 comparisons
      case I32Eqz:
        writeByte(0x45);
      case I32Eq:
        writeByte(0x46);
      case I32Ne:
        writeByte(0x47);
      case I32LtS:
        writeByte(0x48);
      case I32LtU:
        writeByte(0x49);
      case I32GtS:
        writeByte(0x4A);
      case I32GtU:
        writeByte(0x4B);
      case I32LeS:
        writeByte(0x4C);
      case I32LeU:
        writeByte(0x4D);
      case I32GeS:
        writeByte(0x4E);
      case I32GeU:
        writeByte(0x4F);

      // I64 comparisons
      case I64Eqz:
        writeByte(0x50);
      case I64Eq:
        writeByte(0x51);
      case I64Ne:
        writeByte(0x52);
      case I64LtS:
        writeByte(0x53);
      case I64LtU:
        writeByte(0x54);
      case I64GtS:
        writeByte(0x55);
      case I64GtU:
        writeByte(0x56);
      case I64LeS:
        writeByte(0x57);
      case I64LeU:
        writeByte(0x58);
      case I64GeS:
        writeByte(0x59);
      case I64GeU:
        writeByte(0x5A);

      // F32 comparisons
      case F32Eq:
        writeByte(0x5B);
      case F32Ne:
        writeByte(0x5C);
      case F32Lt:
        writeByte(0x5D);
      case F32Gt:
        writeByte(0x5E);
      case F32Le:
        writeByte(0x5F);
      case F32Ge:
        writeByte(0x60);

      // F64 comparisons
      case F64Eq:
        writeByte(0x61);
      case F64Ne:
        writeByte(0x62);
      case F64Lt:
        writeByte(0x63);
      case F64Gt:
        writeByte(0x64);
      case F64Le:
        writeByte(0x65);
      case F64Ge:
        writeByte(0x66);

      // Reference types
      case RefNull(refType):
        writeByte(0xD0);
        writeValueType(refType);
      case RefIsNull:
        writeByte(0xD1);
      case RefFunc(functionIndex):
        writeByte(0xD2);
        writeULEB128(functionIndex);

      // Table operations
      case TableGet(tableIndex):
        writeByte(0x25);
        writeULEB128(tableIndex);
      case TableSet(tableIndex):
        writeByte(0x26);
        writeULEB128(tableIndex);
      case TableSize(tableIndex):
        writeByte(0xFC);
        writeULEB128(12);
        writeULEB128(tableIndex);
      case TableGrow(tableIndex):
        writeByte(0xFC);
        writeULEB128(15);
        writeULEB128(tableIndex);
      case TableFill(tableIndex):
        writeByte(0xFC);
        writeULEB128(17);
        writeULEB128(tableIndex);
      case TableCopy(destTableIndex, srcTableIndex):
        writeByte(0xFC);
        writeULEB128(14);
        writeULEB128(destTableIndex);
        writeULEB128(srcTableIndex);
      case TableInit(elemIndex, tableIndex):
        writeByte(0xFC);
        writeULEB128(12);
        writeULEB128(elemIndex);
        writeULEB128(tableIndex);
      case ElemDrop(elemIndex):
        writeByte(0xFC);
        writeULEB128(13);
        writeULEB128(elemIndex);
    }
  }

  function writeF32(value:Float):Void {
    var bits = haxe.io.FPHelper.floatToI32(value);
    output.writeByte(bits & 0xFF);
    output.writeByte((bits >> 8) & 0xFF);
    output.writeByte((bits >> 16) & 0xFF);
    output.writeByte((bits >> 24) & 0xFF);
  }

  function writeF64(value:Float):Void {
    var bits = haxe.io.FPHelper.doubleToI64(value);
    var low = bits.low;
    var high = bits.high;
    output.writeByte(low & 0xFF);
    output.writeByte((low >> 8) & 0xFF);
    output.writeByte((low >> 16) & 0xFF);
    output.writeByte((low >> 24) & 0xFF);
    output.writeByte(high & 0xFF);
    output.writeByte((high >> 8) & 0xFF);
    output.writeByte((high >> 16) & 0xFF);
    output.writeByte((high >> 24) & 0xFF);
  }
}
