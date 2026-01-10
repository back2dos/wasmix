package wasmix.wasm;

enum ValueType {
  I32;
  I64;
  F32;
  F64;
  V128;
  FuncRef;
  ExternRef;
  RefNull(typeIndex: Int);  // (ref null $type) - typed nullable reference
  Ref(typeIndex: Int);      // (ref $type) - typed non-null reference
}

typedef Limits = {
  min: Int,
  max: Null<Int>
}

typedef TableType = {
  elementType: ValueType,
  limits: Limits
}

typedef MemoryType = {
  limits: Limits
}

typedef GlobalType = {
  valueType: ValueType,
  mutable: Bool
}

typedef FunctionType = {
  params: Array<ValueType>,
  results: Array<ValueType>
}

enum Instruction {
  // Control flow
  Unreachable;
  Nop;
  Block(blockType: BlockType, body: Expression);
  Loop(blockType: BlockType, body: Expression);
  If(blockType: BlockType, thenBody: Expression, elseBody: Null<Expression>);
  Br(labelIndex: Int);
  BrIf(labelIndex: Int);
  BrTable(labelIndices: Array<Int>, defaultLabel: Int);
  Return;
  Call(functionIndex: Int);
  CallIndirect(typeIndex: Int);
  CallRef(typeIndex: Int);
  
  // Parametric
  Drop;
  Select;
  SelectTyped(types: Array<ValueType>);
  
  // Variable access
  LocalGet(localIndex: Int);
  LocalSet(localIndex: Int);
  LocalTee(localIndex: Int);
  GlobalGet(globalIndex: Int);
  GlobalSet(globalIndex: Int);
  
  // Memory
  I32Load(offset: Int, align: Int);
  I64Load(offset: Int, align: Int);
  F32Load(offset: Int, align: Int);
  F64Load(offset: Int, align: Int);
  I32Load8S(offset: Int, align: Int);
  I32Load8U(offset: Int, align: Int);
  I32Load16S(offset: Int, align: Int);
  I32Load16U(offset: Int, align: Int);
  I64Load8S(offset: Int, align: Int);
  I64Load8U(offset: Int, align: Int);
  I64Load16S(offset: Int, align: Int);
  I64Load16U(offset: Int, align: Int);
  I64Load32S(offset: Int, align: Int);
  I64Load32U(offset: Int, align: Int);
  I32Store(offset: Int, align: Int);
  I64Store(offset: Int, align: Int);
  F32Store(offset: Int, align: Int);
  F64Store(offset: Int, align: Int);
  I32Store8(offset: Int, align: Int);
  I32Store16(offset: Int, align: Int);
  I64Store8(offset: Int, align: Int);
  I64Store16(offset: Int, align: Int);
  I64Store32(offset: Int, align: Int);
  MemorySize(memoryIndex: Int);
  MemoryGrow(memoryIndex: Int);
  MemoryInit(dataIndex: Int, memoryIndex: Int);
  DataDrop(dataIndex: Int);
  MemoryCopy(destMemIndex: Int, srcMemIndex: Int);
  MemoryFill(memoryIndex: Int);
  
  // Numeric constants
  I32Const(value: Int);
  I64Const(value: haxe.Int64);
  F32Const(value: Float);
  F64Const(value: Float);
  
  // Numeric operations - I32
  I32Clz;
  I32Ctz;
  I32Popcnt;
  I32Add;
  I32Sub;
  I32Mul;
  I32DivS;
  I32DivU;
  I32RemS;
  I32RemU;
  I32And;
  I32Or;
  I32Xor;
  I32Shl;
  I32ShrS;
  I32ShrU;
  I32Rotl;
  I32Rotr;
  
  // Numeric operations - I64
  I64Clz;
  I64Ctz;
  I64Popcnt;
  I64Add;
  I64Sub;
  I64Mul;
  I64DivS;
  I64DivU;
  I64RemS;
  I64RemU;
  I64And;
  I64Or;
  I64Xor;
  I64Shl;
  I64ShrS;
  I64ShrU;
  I64Rotl;
  I64Rotr;
  
  // Numeric operations - F32
  F32Abs;
  F32Neg;
  F32Ceil;
  F32Floor;
  F32Trunc;
  F32Nearest;
  F32Sqrt;
  F32Add;
  F32Sub;
  F32Mul;
  F32Div;
  F32Min;
  F32Max;
  F32Copysign;
  
  // Numeric operations - F64
  F64Abs;
  F64Neg;
  F64Ceil;
  F64Floor;
  F64Trunc;
  F64Nearest;
  F64Sqrt;
  F64Add;
  F64Sub;
  F64Mul;
  F64Div;
  F64Min;
  F64Max;
  F64Copysign;
  
  // Numeric conversions
  I32WrapI64;
  I32TruncF32S;
  I32TruncF32U;
  I32TruncF64S;
  I32TruncF64U;
  I64ExtendI32S;
  I64ExtendI32U;
  I64TruncF32S;
  I64TruncF32U;
  I64TruncF64S;
  I64TruncF64U;
  F32ConvertI32S;
  F32ConvertI32U;
  F32ConvertI64S;
  F32ConvertI64U;
  F32DemoteF64;
  F64ConvertI32S;
  F64ConvertI32U;
  F64ConvertI64S;
  F64ConvertI64U;
  F64PromoteF32;
  I32ReinterpretF32;
  I64ReinterpretF64;
  F32ReinterpretI32;
  F64ReinterpretI64;
  
  // Numeric comparisons - I32
  I32Eqz;
  I32Eq;
  I32Ne;
  I32LtS;
  I32LtU;
  I32GtS;
  I32GtU;
  I32LeS;
  I32LeU;
  I32GeS;
  I32GeU;
  
  // Numeric comparisons - I64
  I64Eqz;
  I64Eq;
  I64Ne;
  I64LtS;
  I64LtU;
  I64GtS;
  I64GtU;
  I64LeS;
  I64LeU;
  I64GeS;
  I64GeU;
  
  // Numeric comparisons - F32
  F32Eq;
  F32Ne;
  F32Lt;
  F32Gt;
  F32Le;
  F32Ge;
  
  // Numeric comparisons - F64
  F64Eq;
  F64Ne;
  F64Lt;
  F64Gt;
  F64Le;
  F64Ge;
  
  // Reference types
  RefNull(refType: ValueType);
  RefIsNull;
  RefFunc(functionIndex: Int);
  
  // Table operations
  TableGet(tableIndex: Int);
  TableSet(tableIndex: Int);
  TableSize(tableIndex: Int);
  TableGrow(tableIndex: Int);
  TableFill(tableIndex: Int);
  TableCopy(destTableIndex: Int, srcTableIndex: Int);
  TableInit(elemIndex: Int, tableIndex: Int);
  ElemDrop(elemIndex: Int);
}

enum BlockType {
  Empty;
  ValueType(vt: ValueType);
  TypeIndex(index: Int);
}

typedef Expression = Array<Instruction>;

// ============================================================================
// Module Sections
// ============================================================================

enum ImportKind {
  ImportFunction(typeIndex: Int);
  ImportTable(tableType: TableType);
  ImportMemory(memoryType: MemoryType);
  ImportGlobal(globalType: GlobalType);
}

typedef Import = {
  module: String,
  name: String,
  kind: ImportKind
}

enum ExportKind {
  ExportFunction(functionIndex: Int);
  ExportTable(tableIndex: Int);
  ExportMemory(memoryIndex: Int);
  ExportGlobal(globalIndex: Int);
}

typedef Export = {
  name: String,
  kind: ExportKind
}

typedef Function = {
  typeIndex: Int,
  locals: Array<ValueType>,
  body: Expression
}

typedef Global = {
  type: GlobalType,
  init: Expression
}

typedef Element = {
  tableIndex: Int,
  offset: Expression,
  init: Array<Int>
}

typedef DataSegment = {
  memoryIndex: Int,
  offset: Expression,
  init: Array<Int>
}

// ============================================================================
// Module
// ============================================================================

typedef Module = {
  ?types: Array<FunctionType>,
  ?imports: Array<Import>,
  ?functions: Array<Function>,
  ?tables: Array<TableType>,
  ?memories: Array<MemoryType>,
  ?globals: Array<Global>,
  ?exports: Array<Export>,
  ?start: Null<Int>,
  ?elements: Array<Element>,
  ?data: Array<DataSegment>
}

