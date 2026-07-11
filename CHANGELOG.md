# Changelog

## v1.0 — 2026-07-10

First public release.

### Language

- Three file kinds: `.class.laz` (instantiable), `.object.laz` (static namespace), `.trait.laz` (contract)
- Static type system — types checked at compile time, erased before codegen, zero runtime overhead
- Classes with fields, constructors, instance and static methods, public/private visibility
- `.field` shorthand for `self.field` inside instance methods
- Constructor field shorthand: `constructor(.x: int)` auto-declares and assigns
- Enums with data payloads and `match` pattern destructuring
- Traits: `.trait.laz` files, `implement TraitName` for conformance
- `Option<T>` and `Result<T>` with `?` propagation
- Generic functions and enums
- `for` (C-style), `for-in` over List and Map (single value and key-value forms)
- List comprehensions `[x for x in xs if cond]` and map comprehensions `[k: v for k, v in m]`
- f-strings (`f"hello {expr}"`) and triple-quoted strings
- String concatenation with `+` — the typechecker detects string operands and emits Lua `..`
- `extern name(params): Type = "lua.global"` for typed Lua API bindings
- `lua methodName(params): Type { ... }` for inline Lua bodies
- `platform(name)` modifier for platform-gated declarations
- `loop`, `while`, `break`, `return`

### Standard library

- `std.Sys` — print, read, file open, argv, exit, sleep
- `std.Str` — split, trim, pad, find, replace, chars, to_int, to_float
- `std.Num` — floor, ceil, abs, sqrt, clamp, pow, round, to_text
- `std.Path` — join, dirname, basename, stem, ext, is_absolute, normalize
- `std.List` — push, pop, get, len, map, filter, fold, any, all, find, slice, join, reverse
- `std.Map` — get, has, delete, keys, values, len
- `std.Option` — Some/None, is_some, is_none, unwrap, unwrap_or, map
- `std.Result` — Ok/Err, is_ok, is_err, unwrap, unwrap_or, error
- `std.File` — open, read_line, read_all, write, close
- `std.Json` — parse, emit
- `std.Time` — now (platform-gated: os.clock on Lua 5.4, os.time on CC)
- `std.Task` — sleep (platform-gated: task.wait on Roblox, os.sleep on Lua 5.4/CC)

### Compiler

- Self-hosted: source in `compiler/`, compiled output is `bin/lazec.lua`
- Fixpoint verification on every `make selfhost`
- Four optimization levels: `-O0` (default), `-O1`, `-O2`, `-Os` (full name mangling)
- `--check` mode: reports errors as JSON lines without producing output, used by tooling
- `--lib` mode: emits only the entry class block with a `LAZE_META` header for prebuilt libraries
- `--platform <name>` flag for platform-gated builds
- `--pkg-path <dir>` to specify where the standard library lives
- Parser error recovery — reports all errors in a file, not just the first
- Source location comments in emitted Lua (`-- ClassName:line`) for debugging
