# Lazarus

[![CI](https://github.com/NightmarePog/Lazarus/actions/workflows/ci.yml/badge.svg)](https://github.com/NightmarePog/Lazarus/actions/workflows/ci.yml)
[![Docs](https://github.com/NightmarePog/Lazarus/actions/workflows/docs.yml/badge.svg)](https://nightmarepog.github.io/Lazarus/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Language: Lua](https://img.shields.io/badge/target-Lua%205.1-000080.svg)
![Self-hosted](https://img.shields.io/badge/compiler-self--hosted-brightgreen.svg)

Lazarus is a small, statically-typed language that compiles to Lua. The output is a single self-contained `.lua` file with no runtime dependencies, which makes it a good fit for environments where you have Lua but not much else: ComputerCraft computers, embedded scripting runtimes, or anywhere a plain `.lua` file is easier to deploy than a set of modules.

The main thing Lazarus gives you over writing Lua directly is structure. Classes with real constructors, a type system that catches mistakes before runtime, a module system that resolves imports at compile time, and a clean interop layer for calling existing Lua APIs with type signatures.

## Quick example

```
// Counter.class.laz
import std.Sys

private count: int = 0

constructor() { }

increment() {
    .count = .count + 1
}

value(): int {
    return .count
}

static main() {
    mut c = Counter()
    c.increment()
    c.increment()
    Sys.print(f"count: {c.value()}")
}
```

Run it:

```sh
lua bin/lazarusc.lua Counter.class.laz
lua Counter.lua
```

## File kinds

Lazarus has three file kinds, distinguished by the suffix before `.laz`:

| Suffix | Kind | Used for |
|---|---|---|
| `.class.laz` | class | Instantiable types with a constructor and instance methods |
| `.object.laz` | object | Static namespaces -- utility functions, Lua API wrappers |
| `.trait.laz` | trait | Method contracts that classes can implement |

The filename (without the suffix) is the class or module name, so filenames are PascalCase.

## Building

```sh
# Compile a file (output: <ClassName>.lua in the current directory)
lua bin/lazarusc.lua path/to/Entry.class.laz

# Check for errors without producing output
lua bin/lazarusc.lua path/to/File.class.laz --check

# Set optimization level (O0 is default, Os is smallest output)
lua bin/lazarusc.lua Entry.class.laz -O2

# Compile as a library (no entry-point call, exports LAZARUS_META header)
lua bin/lazarusc.lua Lib.class.laz --lib
```

Via make:

```sh
make selfbuild FILE=path/to/Entry.class.laz
```

## Language reference

Documentation: **[nightmarepog.github.io/Lazarus](https://nightmarepog.github.io/Lazarus/)**

Source is in [`doc/design/`](doc/design/).

## Standard library

| Module | Kind | Contents |
|---|---|---|
| `std.Str` | object | String utilities: split, trim, pad, find, replace |
| `std.Sys` | object | IO, process: print, read, file ops, argv, exit |
| `std.Num` | object | Math: floor, ceil, abs, sqrt, clamp, pow |
| `std.Path` | object | File path manipulation |
| `std.List` | class | Ordered list with push, pop, map, filter, fold |
| `std.Map` | class | Key-value map with get, has, delete, keys, values |
| `std.Option` | class | Optional values: Some/None, unwrap, unwrap_or |
| `std.Result` | class | Ok/Err result type, unwrap, unwrap_or, error |
| `std.File` | class | File handle operations |
| `std.Json` | class | JSON serialization |
| `std.Time` | object | Time and clock |
| `std.Task` | object | Async task utilities |

## Compiler development

The compiler is self-hosted: it is written in Lazarus and compiled by the binary it produces. The source lives in `compiler/`. The compiled output is `bin/lazarusc.lua`.

```sh
make selfhost    # rebuild bin/lazarusc.lua from compiler/ (verifies the fixpoint)
make lint        # run selene
make format      # run stylua
```

See [`doc/adding-features.md`](doc/adding-features.md) for how to add a language feature.
Set `LAZARUS_DEBUG=1` to include the Lua stack trace in error output.
