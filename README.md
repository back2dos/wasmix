# WASMIX - WASM In haXe

DISCLAIMER: this library is in early stages of development.

This library allows you to use a subset of Haxe and have it transpiled to WASM.

```haxe
class Example {
  static public function fib(n:Int) {
    return if (n < 2) 1 else fib(n - 1) + fib(n - 2);
  }
}

final example = wasmix.Compile.module(Example);
trace(example.fib(10));// traces 89
```

You can optionally pass a number of flags, like so:

```haxe
wasmix.Compile.module(Example, { async: false, skip: false, validate: false });
```

All flags are false by default, and behave as follows:

- `async` - if set to `true`, you will receive a `Promise` instead of just the instiated module
- `skip` - if set to `true`, you will receive an object with exactly the same structure as the WASM module, but it will run in JavaScript
- `validate` - if set to `true`, will attempt to validate the WASM via whatever nodejs version you have installed. Has no effect for `skip: true`.

## Goal

The goal of this library is to allow you to:

1. Use familiar syntax to write WASM code and rely on Haxe for:
   - auto completion
   - type checking
   - optimizations (e.g. loop unrolling, inlining) ... currently not fully supported, because WASM compilation runs before various filters
   - code organization (structure your code with packages and modules, distribute as normal haxe libraries if you wish)
2. Make calling from Haxe/JS -> WASM and WASM -> Haxe/JS straight forward
3. Produce your WASM during your normal build - the WASM code is currently just embedded in base64 to avoid the need for further bundling etc.
4. Allow to skip WASMification for debugging purposes
5. Avoid relying on external tools (e.g. [WAT](https://component-model.bytecodealliance.org/language-support/building-a-simple-component/wat.html))

This library is *not* intended for running arbitrary Haxe code at the speed of WASM. Support for language features is somewhat limited (you should expect proper compile time errors if you use something unsupported - if you don't, please file a bug). Partly, this is due to lack of resources, but mostly it is by design. The main use case is to offload number crunching into the WASM runtime.

## Supported Types

- `Bool`, `Int`, `Float` and `js.lib.BigInt`: Supported natively as I32, I32, F64 and I64 respectively
- Typed Arrays: in `wasmix.buffer` you will find typed arrays that correspond to those in `js.lib` (the signature differs slightly for various reasons), provided they are in the wasm module's memory - any other typed arrays will throw exceptions.
- Enums: Supported by bridging into Haxe, so constructing/destructuring does come at a significant overhead. For example doubling the value of a `haxe.ds.Option.Some` (read index, read param, construct new `Option`) takes ~5x more time in WASM than Haxe/JS: 20ns vs. 5ns. That still means you can do it 50x in a micro second (or 50000x in a millisecond). Just don't do it in a hot loop.
- Classes: Generally, you can use any Haxe class from WASM, but you should note that methods which are not inlined will have an overhead for bridging. Inlined methods on the other hand will have to be wasmix compatible.
- `abstract` over any supported type. 
- Instances: planned
- Array: planned
- String: planned
- Anonymous object: planned

Please note that anything other than types arrays

### Typed Arrays

Within the WASM runtime, Typed Arrays are passed around as I64, with the low 32 bits being the offset and the high 32 bits being the length. Instead of using `js.lib` you will have to use `wasmix.runtime`. The primary reason is that `js.lib.Float32Array` operates on double precision floats, whereas in WASM we want it to stick to `Float32`. You can always call `toJS` to get the corresponding `js.lib` type to operate on the full interface in JS (it's really just an unsafe cast).

## SIMD

The next biggest thing to figure out will be how to make SIMD instructions available in wasmix in a way that is reasonably readable and can work in JS too. This is currently subject to investigation.