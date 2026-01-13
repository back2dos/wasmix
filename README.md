# WASMIX - WASM In haXe

This library allows you to use a subset of Haxe and have it transpiled to WASM.

```haxe
class Example {
  static public function fib(n:Int) {
    return if (n < 2) 1 else fib(n - 1) + fib(n - 2);
  }
}

wasmix.Compile.module(Example).then(
  wasm -> trace(wasm.fib(10))
);
```

## Goal

The goal of this library is to allow you to:

1. Use familiar syntax to write WASM code and rely on Haxe for:
   - auto completion
   - type checking
   - optimizations (e.g. loop unrolling, inlining)
   - code organization (structure your code with packages and modules, distribute as normal haxe libraries if you wish)
2. Make calling from Haxe/JS -> WASM and WASM -> Haxe/JS straight forward (to the degree that it's possible without tons of glue)
3. Produce your WASM during your normal build - the WASM code is embedded in base64 to avoid the need for further bundling etc.
4. Allow to skip WASMification for debugging purposes
5. Avoid relying on external tools (e.g. [WAT](https://component-model.bytecodealliance.org/language-support/building-a-simple-component/wat.html))

This library is *not* intended for running arbitrary Haxe code at the speed of WASM. Support for types and language features is limited. You should expect proper compile time errors if you use something unsupport (if you don't, please file a bug).

## Supported Types

- Bool, Int, Float: Supported natively as I32, I32 and F64 respectively
- Enum abstracts over Int
- Enums: Supported by bridging into Haxe, so constructing/destructuring does come at a significant overhead. For example doubling the value of a `haxe.ds.Option.Some` (read index, read param, construct new `Option`) takes ~5x more time in WASM than Haxe/JS: 20ns vs. 5ns. That still means you can do it 50x in a micro second (or 50000x in a millisecond). Just don't do it in a hot loop.