# 04 — Types & Data

The type system is **static** and **erased**: types are fully checked in
Schematic and carry no runtime representation, so the emitted Lua pays nothing
for them. There are **no user-defined generics** in v1 — the generic-looking
built-ins are provided by the compiler.

## Primitive types

| Type | Values | Lowers to |
|---|---|---|
| `int` | integers | Lua number |
| `float` | reals | Lua number |
| `bool` | `true`, `false` | Lua boolean |
| `str` | text | Lua string |

`int` and `float` are **distinct** and do not implicitly convert — `int + float`
is a type error; convert explicitly (`x as float`, see strictness below, or a
built-in `to_float(x)`). They are kept separate even though Lua 5.0 stores both
as doubles, so that a future Lua 5.4 backend can map them to real integer/float
without changing any source.

There is **no `nil`** and no truthiness: conditions must be `bool`.

## Option — absence without null

`Option<T>` is the built-in answer to "might be missing":

```
enum Option<T> { Some(T), None }   // conceptual; provided by the compiler
```

```
fn find(self, k: str): Option<int> {
    v = self.table.get(k)      // get returns Option already
    return v
}

match find("a") {
    Some(v) => { use(v) },
    None    => { use_default() },
}
```

`Option` lowers to a plain Lua value: `Some(x)` is just `x`, `None` is Lua `nil`,
under the hood — but the type system forces you to handle the `None` case, so the
`nil` never leaks untyped.

## Result — recoverable errors

`Result` is the error-handling type (there is no exception mechanism and no `?`
operator in v1). It is **not** a built-in generic — v1 has no user generics — so
it is provided by the **stdlib** as a small family of typed classes, each fixing
the Ok type, with the Err side a `str` message:

```
ResultBool      // Ok(bool) | Err(str)
ResultString    // Ok(str)  | Err(str)
ResultInt       // Ok(int)  | Err(str)
```

Construct with the static factories `ok(v)` / `err(m)` and consume with the
query/extract methods. The runtime reserves `unwrap`/`unwrap_or` (for the untyped
extern-boundary Option), so the typed Results use **`take`/`take_or`** instead:

```
import std.ResultString

fn read(self, path: str): ResultString {
    if not self.exists(path) {
        return ResultString.err("no such file: {path}")
    }
    return ResultString.ok(self.load(path))
}

mut r = self.read("cfg")
if r.is_ok() {
    self.parse(r.take())        // the Ok value (panics if called on an Err)
} else {
    self.report(r.error())      // the Err message
}
```

`take()` aborts on an Err via Lua's `error()` (bound as `Sys.panic`); `take_or(d)`
returns a default instead. A new Ok type is supported by adding another
`Result<Type>` class to the stdlib.

## Enums

Enums are **sum types declared inside a class file**. They are **data-only** — no
methods; behavior lives in class functions that `match` on them.

```
enum Shape {
    Empty,
    Circle(float),
    Rect(int, int),
}
```

- Variants are **bare** (`Empty`) or carry a **tuple payload** (`Circle(float)`).
- Construction is **qualified** by the enum: `Shape.Circle(2.0)`, `Shape.Empty`.
- Referenced from another file via the class: `Geometry.Shape.Circle(2.0)`.

### `match`

`match` is a **statement** (it yields no value; assign inside arms or `return`).

```
match shape {
    Circle(r)  => { area = 3.14159 * r * r },
    Rect(w, h) => { area = w * h },
    Empty      => { area = 0.0 },
}
```

- **Arm patterns are bare** (`Circle(r)`), since the enum type is known from the
  scrutinee.
- Patterns **bind payloads** (`Circle(r)` binds `r`).
- `match` must be **exhaustive**: cover every variant or add a `_` wildcard. A
  missing variant is a `SEMANTIC_ERROR`.
- **No guards** in v1 — use a nested `if` inside the arm.
- Arm bodies are blocks (`{ ... }`).

## Collections

### Lists `[T]`

```
xs: [int] = [10, 20, 30]
first = xs[0]            // 0-based; compiles to Lua xs[1]
xs[1] = 99
n = xs.len()
xs.push(40)
last = xs.pop()         // Option<int>
for x in xs { use(x) }
```

### Maps `{K: V}`

```
ages: {str: int} = { "al": 30, "bo": 25 }
ages["cy"] = 40
v = ages.get("al")      // Option<int>  (safe; missing key -> None)
n = ages.len()
for k, val in ages { use(k, val) }
```

**Indexing is 0-based** for lists; the compiler adds the `+1` offset to map onto
Lua's 1-based tables. (This offset applies to Lazarus-native lists only — data
crossing the `extern` / `lua { }` boundary is raw Lua and stays 1-based; see 07.)
`pop`/`get` return `Option` so out-of-range / missing access is type-safe.

Built-in collection methods (v1): `.len()`, `.push(v)`, `.pop(): Option<T>`,
`.get(k): Option<V>` (maps), plus `[i]` read/write.

## Traits

A **trait** is a named contract — a set of method signatures a class can promise
to provide:

```
trait Show {
    fn show(self): str
}
```

A class implements it via an `impl` header and the methods (see
[03-classes.md](03-classes.md)):

```
impl Show
pub fn show(self): str { return "..." }
```

Semantics:
- Traits are **compile-time contracts only**. They let the checker guarantee a
  class has the required methods.
- **No `dyn` / trait objects** in v1 — you cannot hold "some unknown Show" in a
  list. Every method call resolves statically to a concrete class.
- Because there are no user generics yet, a trait's main job in v1 is enforcing
  that a class (often a subclass in a hierarchy) provides an agreed surface.
  `dyn Trait` and generic bounds (`<T: Show>`) are planned for later.

## Strictness, `any`, and `as`

Anything crossing the Lua boundary (`lua { }`, an unmodelled `extern` value) has
type **`any`** — "could be anything." A project/file **strictness** setting,
**strict by default**, controls how `any` may be used:

- **Strict (default):** an `any` must be **`as`-asserted** to a concrete type
  before it is used in typed code. `x as int` is an **unchecked assertion** — you
  vouch for it, there is no runtime check (think Rust's `unsafe` cast). Misuse is
  your responsibility.
- **Loose:** `any` flows implicitly into any slot; `as` is optional. Convenient
  for prototyping, weaker guarantees.

```
// strict
t = lua { os.time() } as int     // assertion required to use as int
// loose
t = lua { os.time() }            // stays any, flows freely
```

`as` exists only for this boundary assertion in v1; it is **not** a general
numeric-conversion operator (use built-in conversions like `to_float` for that).
