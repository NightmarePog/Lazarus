# Collection HOF — Design Spec

Date: 2026-07-02

## What we're building

Six higher-order functions (`map`, `filter`, `fold`, `any`, `all`, `find`) for
`List<T>` and `Map<K,V>`, delivered as two stdlib static modules plus a shared
`Iterable<T>` interface for user-defined collection classes.

## Files

### `std/Iterable.laz`

An otherwise-empty file that declares the `Iterable<T>` interface inline.
`#interface` files are non-generic so the inline form is required.
User-defined collection classes `import Iterable` and implement the contract;
the structural checker verifies conformance automatically.

```laz
interface Iterable<T> {
    map<U>(f: (T) -> U): List<U>
    filter(f: (T) -> bool): List<T>
    fold<A>(init: A, f: (A, T) -> A): A
    any(f: (T) -> bool): bool
    all(f: (T) -> bool): bool
    find(f: (T) -> bool): Option<T>
}
```

### `std/List.laz`

`#object` static module. Each function is generic; the list is the first arg.
Bodies use plain `for x in xs` loops — no new language features required.

Functions: `map<T,U>`, `filter<T>`, `fold<T,A>`, `any<T>`, `all<T>`, `find<T>`.

### `std/Map.laz`

`#object` static module. Map callbacks take two arguments `(k, v)` — no tuple
type exists, so `Map<K,V>` does not satisfy `Iterable<T>`. Follows the same
ergonomic pattern.

- `map<K,V,U>` — maps values, preserves keys → `Map<K,U>`
- `filter<K,V>` → `Map<K,V>`
- `fold<K,V,A>` — 3-arg accumulator `(A, K, V) -> A`
- `any<K,V>`, `all<K,V>` — 2-arg predicate `(K, V) -> bool`
- `find<K,V>` → `Option<V>` (returns the value)

Bodies use `for k, v in m` loops.

## Design decisions

- **Built-ins don't satisfy `Iterable<T>`** — `List<T>` and `Map<K,V>` are
  primitive tagged-tables, not classes. Extending the checker to unify them with
  `Iterable<T>` is out of scope; the static modules handle them directly.
- **`Iterable<T>` is for user classes** — any class with matching method
  signatures is structurally accepted wherever `Iterable<T>` is expected.
- **Map HOF are not `Iterable<T>`** — the 2-arg callback shape is incompatible
  with the 1-arg `Iterable<T>` contract. Map gets its own standalone module.
- **No new language features needed** — all implementations are valid Lazarus
  today: generics, `fn` expressions, `for-in`, `Option.some/none`.

## Usage

```laz
import List
import Map
import Iterable   // only needed if declaring a conforming class

nums: List<int> = [1, 2, 3, 4, 5]
doubled  = List.map(nums, fn(x: int): int { return x * 2 })
evens    = List.filter(nums, fn(x: int): bool { return x % 2 == 0 })
sum      = List.fold(nums, 0, fn(acc: int, x: int): int { return acc + x })
has_big  = List.any(nums, fn(x: int): bool { return x > 4 })
all_pos  = List.all(nums, fn(x: int): bool { return x > 0 })
first_gt3 = List.find(nums, fn(x: int): bool { return x > 3 })

scores: Map<str, int> = ["alice": 10, "bob": 5]
doubled_scores = Map.map(scores, fn(k: str, v: int): int { return v * 2 })
```

## Out of scope

- Method-call syntax `xs.map(f)` — would require emitter special-casing
- Chaining `List.map(...).filter(...)` — return types already enable this via
  repeated calls; no special syntax needed
- Teaching the checker that `List<T>` satisfies `Iterable<T>`
