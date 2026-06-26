# Lazarus stdlib

Hand-written Lazarus stdlib. `std` is a normal folder at your project root, so
import these with a dotted, root-relative path:

```
import std.Str
import std.ResultString
```

(Stdlib files import each other the same way, e.g. `import std.Sys` — every
import resolves from the project root, never relative to the importing file.)

## Extern namespaces

Thin wrappers over Lua's stdlib via the `extern` mechanism. Every extern call
forwards its args (no arity check) and wraps its result at the **Option boundary**
— a Lua `nil` becomes the untyped runtime `None`, any other value `Some` — so the
result is consumed with the builtin `.unwrap()` / `.is_some()` / `.unwrap_or(d)`.

| File | Wraps | Notes |
|------|-------|-------|
| `Str.laz` | `string.*` | `find` uses the single-return shim `__lz_str_find` (returns the 1-based match start, or `None`). |
| `Num.laz` | `math.*` + `tonumber` | `to_number` returns `None` for a non-numeric string. |
| `Sys.laz` | `io.*` / `os.*` / `print` | `panic(msg)` binds to Lua `error()` and never returns. |

## Typed Option / Result

Type safety by convention: each class only ever holds one kind of value (there is
no type system to enforce it). These are plain Lazarus classes — **not** the
untyped runtime Option produced at the extern boundary.

The runtime reserves the method names `unwrap`/`unwrap_or`/`is_some`/`is_none`, so
the typed classes use distinct names:

- **`ResultBool` / `ResultString` / `ResultInt`** — `Ok(<type>) | Err(str)`.
  Build with `ResultX.ok(v)` / `ResultX.err(m)`; query with `is_ok()` / `is_err()`;
  extract with `take()` (aborts via `Sys.panic` on `Err`) / `take_or(d)`; read the
  error message with `error()`.
- **`OptionBool` / `OptionString` / `OptionInt`** — `Some(<type>) | None`.
  Build with `OptionX.some(v)` / `OptionX.none()`; query with `present()` /
  `absent()`; extract with `take()` / `take_or(d)`.

Add a new Ok/Some type by copying the corresponding class and changing the Err/None
placeholder value.
