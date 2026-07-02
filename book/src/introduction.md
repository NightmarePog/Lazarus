# The Lazarus Language Reference

Lazarus is a statically-typed, class-oriented language that compiles to a single self-contained Lua file. It is designed to be a more readable, safer dialect of Lua with a modern type system that is fully erased at code generation — zero runtime type cost.

## Design principles

- **File = class.** Every `.laz` file is a class. The filename (in `PascalCase`) is the class name.
- **Static types, erased output.** Types are checked at compile time and removed from the generated Lua. No type tables, no runtime overhead.
- **Compiles to one file.** `lazarusc` bundles all imports into a single `.lua`. No runtime `require`.
- **Target runtime: Lua 5.x.** The output is plain Lua 5.0-compatible code.

## Pipeline

```
Source (.laz)
  → Lexer       (tokens)
  → Parser      (AST)
  → Schematic   (name resolution, type checking)
  → Optimizer   (constant folding)
  → Codegen     (Lua source)
```

## Status

This reference documents what the compiler currently implements. Features listed in the design documents but not yet compiled are not covered here.
