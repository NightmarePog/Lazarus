# Collection HOF — Design Spec (v2)

Date: 2026-07-02  
Updated: 2026-07-02 (Option 2 — compile-time dispatch)

## What we're building

Six higher-order functions (`map`, `filter`, `fold`, `any`, `all`, `find`) for
`List<T>` and `Map<K,V>`, callable with OOP method syntax at zero runtime cost.

```laz
nums.map(fn(x: int): int { return x * 2 })
nums.filter(fn(x: int): bool { return x > 1 })
nums.fold(0, fn(acc: int, x: int): int { return acc + x })
```

## Dispatch model — C++ style compile-time rewrite

`xs.map(f)` in Lazarus compiles to `List.map(xs, f)` in Lua. The type checker
resolves the method at compile time (it knows `xs: List<T>`), annotates the AST
node with `dispatch_class: "List"`, and the emitter uses that annotation to rewrite
the call. Zero runtime cost — no metatables, no vtables, no method copying.

For `dynamic` receivers the compile-time lookup fails — the compiler errors
with "cannot dispatch method on dynamic value." This is correct: `dynamic` opts
out of the type system, so compile-time dispatch isn't available.

User-defined classes that implement `Iterable<T>` define the HOF as ordinary
instance methods and use the existing method dispatch — no special treatment needed.

## Files

### `std/Iterable.laz` (already done ✅)

Inline `interface Iterable<T>` — structural contract for user-defined collection
classes. Methods match the HOF signatures. Fully erased.

### `std/List.laz`

`#object` static module. Each HOF is a generic static method with the list as
the **first parameter** (the implicit self):

```laz
#object

map<T, U>(xs: List<T>, f: (T) -> U): List<U> { ... }
filter<T>(xs: List<T>, f: (T) -> bool): List<T> { ... }
fold<T, A>(xs: List<T>, init: A, f: (A, T) -> A): A { ... }
any<T>(xs: List<T>, f: (T) -> bool): bool { ... }
all<T>(xs: List<T>, f: (T) -> bool): bool { ... }
find<T>(xs: List<T>, f: (T) -> bool): Option<T> { ... }
```

### `std/Map.laz`

`#object` static module. Map callbacks take `(k, v)` — no tuple type exists.
`map` preserves keys → `Map<K,U>`. `find` returns the value → `Option<V>`.

```laz
#object

map<K, V, U>(m: Map<K, V>, f: (K, V) -> U): Map<K, U> { ... }
filter<K, V>(m: Map<K, V>, f: (K, V) -> bool): Map<K, V> { ... }
fold<K, V, A>(m: Map<K, V>, init: A, f: (A, K, V) -> A): A { ... }
any<K, V>(m: Map<K, V>, f: (K, V) -> bool): bool { ... }
all<K, V>(m: Map<K, V>, f: (K, V) -> bool): bool { ... }
find<K, V>(m: Map<K, V>, f: (K, V) -> bool): Option<V> { ... }
```

### `compiler/frontend/typecheck/Typecheck.laz`

Extend built-in method dispatch. When `xs: List<T>` (or `Map<K,V>`) and the
method name is NOT in the hardcoded built-in table (`push`, `pop`, etc.):

1. Look up the method in `classes["List"]` (or `classes["Map"]`) static methods
2. Run the existing `infer_and_check` generic resolution with `xs` as first arg
3. Annotate the call node: `call.set("dispatch_class", "List")`
4. Return the substituted return type

### `compiler/backend/ExprEmitter.laz`

When emitting a method call that has `dispatch_class` set on the node:

```lua
-- instead of: xs.map(xs, f)   ← would crash (map not on tagged table)
-- emit:       List.map(xs, f)  ← correct static dispatch
```

Read `node.attr("dispatch_class")` and emit `DispatchClass.method(receiver, args...)`.

## Call syntax vs. emitted Lua

| Lazarus source | Lua output |
|---|---|
| `nums.map(fn(x: int): int { return x * 2 })` | `List.map(nums, function(x) return x * 2 end)` |
| `scores.filter(fn(k: str, v: int): bool { return v > 5 })` | `Map.filter(scores, function(k, v) return v > 5 end)` |
| `nums.fold(0, fn(acc: int, x: int): int { return acc + x })` | `List.fold(nums, 0, function(acc, x) return acc + x end)` |

## Conformance note

`List<T>` and `Map<K,V>` are built-in primitives — they don't formally satisfy
`Iterable<T>` in the type checker. The compile-time dispatch is a separate
mechanism. `Iterable<T>` is for user-defined collection classes that define the
HOF as instance methods.

## Out of scope

- `dynamic` receiver dispatch (type unknown at compile time → error)
- Chaining `xs.map(f).filter(g)` — the return type of `map` is `List<U>`, which
  is a typed value, so `.filter(g)` on it will resolve correctly via the same
  dispatch mechanism. Chaining works automatically.
- Metatables / vtables — explicitly rejected for performance
- Method syntax for the 11 existing `#object` util modules (Text, Str, etc.)
