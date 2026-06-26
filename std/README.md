# Lazarus stdlib

Hand-written Lazarus stdlib. `std` is a normal folder at your project root, so
import these with a dotted, root-relative path:

```
import std.Str
import std.Sys
```

(Stdlib files import each other the same way, e.g. `import std.Sys` — every
import resolves from the project root, never relative to the importing file.)

## Extern namespaces

Thin wrappers over Lua's stdlib via the `extern` mechanism. Every extern call
forwards its args (no arity check) and wraps its result at the **Option boundary**
— a Lua `nil` becomes a `None`, any other value `Some(v)` — so the result is
consumed with `.is_some()` / `.unwrap()` / `.unwrap_or(d)`.

| File | Wraps | Notes |
|------|-------|-------|
| `Str.laz` | `string.*` | `find` uses the single-return shim `__lz_str_find` (returns the 1-based match start, or `None`). |
| `Num.laz` | `math.*` + `tonumber` | `to_number` returns `None` for a non-numeric string. |
| `Sys.laz` | `io.*` / `os.*` / `print` | `panic(msg)` binds to Lua `error()` and never returns. |

## Built-in collections, Option and Result

`List<T>`, `Map<K,V>`, `Option<T>` and `Result<T>` are **language built-ins**, not
std files — for speed they lower to lightweight tagged tables (`{ kind = … }`)
with direct `__lz_*` helpers (no method dispatch, no per-instance method copies).
No import is needed.

- **`List<T>`** — the `[a, b, c]` literal. `get(i)`/`pop()` → `Option<T>`,
  `push(x)`, `len()`, `has(k)`; index with `xs[i]`; iterate with `for x in xs`.
- **`Map<K,V>`** — the `["k": v]` / `[:]` literal. `get(k)` → `Option<V>`,
  `has(k)`, `len()`; index with `m[k]`; iterate with `for k, v in m`.
- **`Option<T>`** — build with `Option.some(v)` / `Option.none()`; query with
  `is_some()` / `is_none()`; extract with `unwrap()` (aborts on `None`) /
  `unwrap_or(d)`. Every collection/IO/extern result is an `Option<T>`.
- **`Result<T>`** — build with `Result.ok(v)` / `Result.err(m)`; query with
  `is_ok()` / `is_err()`; extract with `unwrap()` / `unwrap_or(d)`; read the error
  message with `error()`.
