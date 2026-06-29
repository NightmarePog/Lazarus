# Collection HOF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `map`, `filter`, `fold`, `any`, `all`, `find` to `std/List.laz` and `std/Map.laz` as generic static HOF, plus a shared `Iterable<T>` interface for user-defined collection classes.

**Architecture:** Three pure-additive stdlib files. No compiler changes. `std/Iterable.laz` holds only an `interface Iterable<T>` inline declaration (the `#interface` file form is non-generic, so inline is required). `std/List.laz` and `std/Map.laz` are `#object` static modules whose function bodies use existing `for-in` + built-in `push`/`Option.some/none`. All HOF are generic — the parser already supports `<T, U>` on function declarations; `callable_var_set` threads them through the type checker.

**Tech Stack:** Lazarus, Lua 5.1 runtime, `lua bin/lazarusc.lua` to compile, `lua Main.lua` to run.

---

## File map

| File | Action | Responsibility |
|---|---|---|
| `std/Iterable.laz` | Create | Inline `interface Iterable<T>` — contract for user-defined collection classes |
| `std/List.laz` | Create | `#object` with 6 generic HOF for `List<T>` |
| `std/Map.laz` | Create | `#object` with 6 generic HOF for `Map<K,V>` |
| `examples/CollectionHOF.laz` | Create | Integration test program — compiles + runs to verify correctness |

---

## Task 1: `std/Iterable.laz`

**Files:**
- Create: `std/Iterable.laz`

- [ ] **Step 1: Create the file**

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

The file body is a single `InterfaceDecl` node. The linker's `body_is_interface` check returns `true` for this (all nodes are `InterfaceDecl`), so it skips Schematic + Typecheck + Codegen — nothing is emitted. `Main.collect_interfaces` registers `Iterable` in the program-wide `interfaces` map; any class importing this file and matching the signatures satisfies it structurally.

- [ ] **Step 2: Smoke-test the import**

Write a one-liner test file to confirm the file parses and loads:

```
lua bin/lazarusc.lua std/Iterable.laz
```

Expected: `Main.lua` written (empty class, no errors). Run `lua Main.lua` → silent exit.

- [ ] **Step 3: Commit**

```bash
git add std/Iterable.laz
git commit -m "feat(std): Iterable<T> interface — contract for collection classes"
```

---

## Task 2: `std/List.laz`

**Files:**
- Create: `std/List.laz`

- [ ] **Step 1: Create the file**

```laz
#object

map<T, U>(xs: List<T>, f: (T) -> U): List<U> {
    mut result = []
    for x in xs { result.push(f(x)) }
    return result
}

filter<T>(xs: List<T>, f: (T) -> bool): List<T> {
    mut result = []
    for x in xs { if f(x) { result.push(x) } }
    return result
}

fold<T, A>(xs: List<T>, init: A, f: (A, T) -> A): A {
    mut acc = init
    for x in xs { acc = f(acc, x) }
    return acc
}

any<T>(xs: List<T>, f: (T) -> bool): bool {
    for x in xs { if f(x) { return true } }
    return false
}

all<T>(xs: List<T>, f: (T) -> bool): bool {
    for x in xs { if !f(x) { return false } }
    return true
}

find<T>(xs: List<T>, f: (T) -> bool): Option<T> {
    for x in xs { if f(x) { return Option.some(x) } }
    return Option.none()
}
```

Implementation notes:
- `mut result = []` — unannotated local infers `dynamic`; gradual mode defers all checks on it. `return result` where return type is `List<U>` passes because dynamic defers.
- `mut acc = init` — same: `init: A` is a type var; local is untyped; dynamic defers through.
- `for x in xs` lowers to `for _, x in __lz_each(xs)` — already correct for `List<T>`.
- `result.push(...)` on a dynamic local maps to the built-in list push helper.
- `Option.some(x)` / `Option.none()` are built-in emitter calls — no import needed.

- [ ] **Step 2: Compile the file standalone**

```
lua bin/lazarusc.lua std/List.laz
```

Expected: no type errors, `Main.lua` written. Run `lua Main.lua` → silent exit (the `#object` file emits an empty constructor body).

- [ ] **Step 3: Commit**

```bash
git add std/List.laz
git commit -m "feat(std): List HOF — map, filter, fold, any, all, find"
```

---

## Task 3: `std/Map.laz`

**Files:**
- Create: `std/Map.laz`

- [ ] **Step 1: Create the file**

```laz
#object

map<K, V, U>(m: Map<K, V>, f: (K, V) -> U): Map<K, U> {
    mut result = [:]
    for k, v in m { result[k] = f(k, v) }
    return result
}

filter<K, V>(m: Map<K, V>, f: (K, V) -> bool): Map<K, V> {
    mut result = [:]
    for k, v in m { if f(k, v) { result[k] = v } }
    return result
}

fold<K, V, A>(m: Map<K, V>, init: A, f: (A, K, V) -> A): A {
    mut acc = init
    for k, v in m { acc = f(acc, k, v) }
    return acc
}

any<K, V>(m: Map<K, V>, f: (K, V) -> bool): bool {
    for k, v in m { if f(k, v) { return true } }
    return false
}

all<K, V>(m: Map<K, V>, f: (K, V) -> bool): bool {
    for k, v in m { if !f(k, v) { return false } }
    return true
}

find<K, V>(m: Map<K, V>, f: (K, V) -> bool): Option<V> {
    for k, v in m { if f(k, v) { return Option.some(v) } }
    return Option.none()
}
```

Implementation notes:
- `for k, v in m` lowers to `for k, v in __lz_each(m)` — already correct for `Map<K,V>`.
- `mut result = [:]` — empty map literal; local is untyped dynamic; return type `Map<K,U>` defers.
- `result[k] = f(k, v)` — index-assign on a dynamic local uses `__lz_idx_set`.
- `Map.map` preserves keys and maps values → `Map<K,U>`. `find` returns the value, not the key → `Option<V>`.
- `f: (K, V) -> U` is a 2-arg function type; `fold`'s `f: (A, K, V) -> A` is 3-arg. Both are valid `TypeFn` nodes (parser loops over params).

- [ ] **Step 2: Compile the file standalone**

```
lua bin/lazarusc.lua std/Map.laz
```

Expected: no type errors, `Main.lua` written. Run `lua Main.lua` → silent exit.

- [ ] **Step 3: Commit**

```bash
git add std/Map.laz
git commit -m "feat(std): Map HOF — map, filter, fold, any, all, find"
```

---

## Task 4: Integration test

**Files:**
- Create: `examples/CollectionHOF.laz`

- [ ] **Step 1: Write the test program**

```laz
import std.List
import std.Map
import std.Sys

constructor() {
    // ---- List HOF ----
    nums: List<int> = [1, 2, 3, 4, 5]

    // map
    doubled = List.map(nums, fn(x: int): int { return x * 2 })
    if doubled.get(0).unwrap() != 2 { Sys.panic("map[0]") }
    if doubled.get(2).unwrap() != 6 { Sys.panic("map[2]") }
    if doubled.len() != 5 { Sys.panic("map len") }

    // filter
    evens = List.filter(nums, fn(x: int): bool { return x % 2 == 0 })
    if evens.len() != 2 { Sys.panic("filter len") }
    if evens.get(0).unwrap() != 2 { Sys.panic("filter[0]") }
    if evens.get(1).unwrap() != 4 { Sys.panic("filter[1]") }

    // fold
    sum = List.fold(nums, 0, fn(acc: int, x: int): int { return acc + x })
    if sum != 15 { Sys.panic("fold sum") }

    // any
    if !List.any(nums, fn(x: int): bool { return x > 4 }) { Sys.panic("any true") }
    if List.any(nums, fn(x: int): bool { return x > 10 }) { Sys.panic("any false") }

    // all
    if !List.all(nums, fn(x: int): bool { return x > 0 }) { Sys.panic("all true") }
    if List.all(nums, fn(x: int): bool { return x > 3 }) { Sys.panic("all false") }

    // find
    found = List.find(nums, fn(x: int): bool { return x > 3 })
    if !found.is_some() { Sys.panic("find some") }
    if found.unwrap() != 4 { Sys.panic("find value") }
    missing = List.find(nums, fn(x: int): bool { return x > 99 })
    if !missing.is_none() { Sys.panic("find none") }

    // ---- Map HOF ----
    scores: Map<str, int> = ["alice": 10, "bob": 5]

    // map
    doubled_scores = Map.map(scores, fn(k: str, v: int): int { return v * 2 })
    if doubled_scores.get("alice").unwrap() != 20 { Sys.panic("map.map alice") }
    if doubled_scores.get("bob").unwrap() != 10 { Sys.panic("map.map bob") }

    // filter
    high = Map.filter(scores, fn(k: str, v: int): bool { return v > 7 })
    if !high.has("alice") { Sys.panic("filter has alice") }
    if high.has("bob") { Sys.panic("filter no bob") }

    // fold
    total = Map.fold(scores, 0, fn(acc: int, k: str, v: int): int { return acc + v })
    if total != 15 { Sys.panic("map.fold total") }

    // any
    if !Map.any(scores, fn(k: str, v: int): bool { return v > 9 }) { Sys.panic("map.any true") }
    if Map.any(scores, fn(k: str, v: int): bool { return v > 99 }) { Sys.panic("map.any false") }

    // all
    if !Map.all(scores, fn(k: str, v: int): bool { return v > 0 }) { Sys.panic("map.all true") }
    if Map.all(scores, fn(k: str, v: int): bool { return v > 9 }) { Sys.panic("map.all false") }

    // find
    top = Map.find(scores, fn(k: str, v: int): bool { return v > 9 })
    if !top.is_some() { Sys.panic("map.find some") }
    if top.unwrap() != 10 { Sys.panic("map.find value") }

    Sys.print("collection HOF: all assertions passed")
}
```

- [ ] **Step 2: Compile**

```
lua bin/lazarusc.lua examples/CollectionHOF.laz
```

Expected: no type errors or parse errors. `Main.lua` written.

- [ ] **Step 3: Run**

```
lua Main.lua
```

Expected output:
```
collection HOF: all assertions passed
```

If any assertion panics, the error message tells you which HOF/case failed. Fix the corresponding stdlib function and recompile.

- [ ] **Step 4: Commit**

```bash
git add examples/CollectionHOF.laz
git commit -m "test(examples): CollectionHOF — integration test for List/Map HOF"
```

---

## Task 5: Selfhost fixpoint

The new stdlib files are purely additive — the compiler itself doesn't import them, so the selfhost fixpoint should be unaffected. Verify:

- [ ] **Step 1: Run selfhost**

```
make selfhost
```

Expected: `stage1 == stage2` byte-exact fixpoint, binary installed to `bin/lazarusc.lua`. No errors.

- [ ] **Step 2: Commit if `bin/lazarusc.lua` changed**

If the binary changed (unlikely but possible due to a compiler source file being on the branch), stage it:

```bash
git add bin/lazarusc.lua
git commit -m "chore: regenerate bin/lazarusc.lua after selfhost fixpoint"
```

If it did not change, no commit needed.

---

## Troubleshooting

**"unknown annotation" or parse error in std/List.laz** — check that `#object` is the first token. The directive is parsed as `HASH` + identifier `object`; `object` is not a keyword so must appear immediately after `#` with no spaces lost.

**TypeError on `return result`** — the local `mut result = []` is typed `dynamic`; the return type is `List<U>`. The checker defers because `dynamic` is one side of the compatibility check. If this errors, add an explicit cast annotation: `mut result: List<U> = []` — but note `U` as a local annotation requires it to be in `type_vars` (it is, via `callable_var_set`).

**TypeError on `acc = f(acc, x)`** — `f` is typed as `(A, T) -> A`. If the checker can't call a `Type.func` value, check that `type_expr` for `CallExpr` handles `Type.func` receivers (it should — closures are already tested in the compiler).

**`Sys.panic` fires at runtime** — the assertion message tells you which case. Check the corresponding function body and the Lua output in `Main.lua` to debug.
