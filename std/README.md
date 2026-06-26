# Lazarus stdlib

Hand-written Lazarus stdlib. `std` is a normal folder at your project root, so
import these with a dotted, root-relative path:

```
import std.Str
import std.Option
```

(Stdlib files import each other the same way, e.g. `import std.Sys` — every
import resolves from the project root, never relative to the importing file.)

## Extern namespaces

Thin wrappers over Lua's stdlib via the `extern` mechanism. Every extern call
forwards its args (no arity check) and wraps its result at the **Option boundary**
— a Lua `nil` becomes `Option.none()`, any other value `Option.some(v)` — so the
result is consumed with `.is_some()` / `.unwrap()` / `.unwrap_or(d)`.

| File | Wraps | Notes |
|------|-------|-------|
| `Str.laz` | `string.*` | `find` uses the single-return shim `__lz_str_find` (returns the 1-based match start, or `None`). |
| `Num.laz` | `math.*` + `tonumber` | `to_number` returns `None` for a non-numeric string. |
| `Sys.laz` | `io.*` / `os.*` / `print` | `panic(msg)` binds to Lua `error()` and never returns. |

## Option / Result

There is **one** `Option<T>` and **one** `Result<T>`, generic over their element
type — no per-type copies. They are ordinary Lazarus classes, type-checked like
any other generic class, and the type argument is inferred at construction
(`Option.some(5)` is an `Option<int>`).

`Option<T>` and `Result<T>` are also the language's *runtime* optional types:
collection and IO operations (`list.get`, `list.pop`, `Sys.read_line`, every
extern result) return an `Option<T>`. They are linked into every program
implicitly, so you can consume a collection result without importing them; import
them explicitly when you name the type or call the static factories.

- **`Option<T>`** — `Some(T) | None`. Build with `Option.some(v)` /
  `Option.none()`; query with `is_some()` / `is_none()`; extract with `unwrap()`
  (aborts via `Sys.panic` on `None`) / `unwrap_or(d)`.
- **`Result<T>`** — `Ok(T) | Err(str)`. Build with `Result.ok(v)` /
  `Result.err(m)`; query with `is_ok()` / `is_err()`; extract with `unwrap()`
  (aborts via `Sys.panic` with the message on `Err`) / `unwrap_or(d)`; read the
  error message with `error()`.

The `None`/`Err` placeholder element value is erased and never observed.
