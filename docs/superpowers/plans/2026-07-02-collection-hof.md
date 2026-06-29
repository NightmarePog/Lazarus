# Collection HOF Implementation Plan (v2 — compile-time dispatch)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `map`, `filter`, `fold`, `any`, `all`, `find` to `List<T>` and `Map<K,V>` with OOP method syntax (`xs.map(f)`) that compiles to a static dispatch (`List.map(xs, f)`) at zero runtime cost — C++-style, no metatables, no method copying.

**Architecture:** `std/List.laz` and `std/Map.laz` are `#object` static modules whose HOF take the collection as the first param. The type checker, when it sees `xs.map(f)` on a built-in type, looks up the method in the imported class's static methods, annotates the call node with `dispatch_class`, and the emitter uses that annotation to emit `List.map(xs, f)`. `std/Iterable.laz` (already done) holds the `Iterable<T>` interface for user-defined collection classes. `dynamic` receivers do not dispatch (compile error).

**Tech Stack:** Lazarus compiler (self-hosted). Relevant files: `compiler/frontend/typecheck/Typecheck.laz`, `compiler/backend/ExprEmitter.laz`, `std/List.laz`, `std/Map.laz`. Verify with `make selfhost`.

---

## File map

| File | Action | Responsibility |
|---|---|---|
| `std/Iterable.laz` | ✅ Done | `interface Iterable<T>` — contract for user-defined collection classes |
| `std/List.laz` | Create | `#object` with 6 generic HOF; first param is the receiver list |
| `std/Map.laz` | Create | `#object` with 6 generic HOF; first param is the receiver map |
| `compiler/frontend/typecheck/Typecheck.laz` | Modify | Extend `type_method_call` to dispatch HOF on built-in types to static class methods |
| `compiler/backend/ExprEmitter.laz` | Modify | Read `dispatch_class` annotation and emit `Class.method(receiver, args...)` |
| `examples/CollectionHOF.laz` | Create | Integration test using `xs.map(f)` syntax; compiles and runs |

---

## Task 1: `std/List.laz`

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

Notes:
- `mut result = []` — unannotated local is `dynamic`; gradual mode defers all checks. Return type `List<U>` passes because `dynamic` defers.
- `mut acc = init` — same: local is untyped; dynamic defers through.
- `for x in xs` lowers to `for _, x in __lz_each(xs)` — correct for `List<T>`.
- `Option.some(x)` / `Option.none()` are built-in emitter calls — no import needed.

- [ ] **Step 2: Compile standalone**

```
cd /home/nightmare/Github/Lazarus
lua bin/lazarusc.lua std/List.laz
lua Main.lua
```

Expected: no errors, `Main.lua` written (empty `#object` stub), silent exit.

- [ ] **Step 3: Commit**

```bash
git add std/List.laz
git commit -m "feat(std): List HOF static module — map, filter, fold, any, all, find"
```

---

## Task 2: `std/Map.laz`

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

Notes:
- `for k, v in m` lowers to `for k, v in __lz_each(m)` — correct for `Map<K,V>`.
- `mut result = [:]` — empty map literal; untyped local; return type defers.
- `result[k] = f(k, v)` — index-assign on dynamic local uses `__lz_idx_set`.
- `map` preserves keys and maps values → `Map<K,U>`. `find` returns the value → `Option<V>`.
- `f: (K, V) -> U` is a 2-arg function type; `fold`'s `f: (A, K, V) -> A` is 3-arg. Both valid `TypeFn` nodes.

- [ ] **Step 2: Compile standalone**

```
lua bin/lazarusc.lua std/Map.laz
lua Main.lua
```

Expected: no errors, silent exit.

- [ ] **Step 3: Commit**

```bash
git add std/Map.laz
git commit -m "feat(std): Map HOF static module — map, filter, fold, any, all, find"
```

---

## Task 3: Type checker dispatch

**Files:**
- Modify: `compiler/frontend/typecheck/Typecheck.laz`

### Context

`type_method_call` (line 726) currently routes all built-in type method calls through `builtin_method` which only knows about `push`, `pop`, `get`, `len`, `has`, etc. For HOF, we extend the path: if the method is NOT in the hardcoded built-in set, try the `classes` registry for `recv.name` (e.g., `classes["List"]`). If a matching static method is found, annotate the call node with `dispatch_class` and use `type_method_sig` for full generic inference.

**Key insight:** The HOF methods take the collection as their FIRST param (`xs: List<T>`). We prepend the receiver AST node to the call args so `infer_and_check` sees the full argument list `[xs_node, f_node]` and can unify `T=int` from the first arg. `receiver_subst` returns `{}` for `#object` modules (no class-level type params), so all unification happens through `infer_and_check`.

### What `type_method_call` looks like now (line 726–764)

```laz
private type_method_call(member: Node, args: List<Node>, scope: Scope, call: Node): Type {
    mut object = member.child("object")
    mut method = member.child("field")
    mut recv = .receiver_type(object, scope)
    if .is_builtin_type(recv) {
        return .builtin_method(recv, method, args, scope)
    }
    // ... rest unchanged
```

### What it should look like after the change

```laz
private type_method_call(member: Node, args: List<Node>, scope: Scope, call: Node): Type {
    mut object = member.child("object")
    mut method = member.child("field")
    mut recv = .receiver_type(object, scope)
    if .is_builtin_type(recv) {
        mut class_entry = .classes.get(recv.name)
        if class_entry.is_some() {
            mut sig = class_entry.unwrap().get("methods").unwrap().get(method)
            if sig.is_some() and sig.unwrap().get("is_static").unwrap_or(false) {
                call.set("dispatch_class", recv.name)
                mut full_args = [object]
                for arg in args { full_args.push(arg) }
                return .type_method_sig(recv.name, recv, sig.unwrap(), full_args, scope, call)
            }
        }
        return .builtin_method(recv, method, args, scope)
    }
    // ... rest unchanged
```

- [ ] **Step 1: Apply the change to `compiler/frontend/typecheck/Typecheck.laz`**

Find the `type_method_call` function (around line 726). Change the `if .is_builtin_type(recv)` block from:

```laz
    if .is_builtin_type(recv) {
        return .builtin_method(recv, method, args, scope)
    }
```

To:

```laz
    if .is_builtin_type(recv) {
        mut class_entry = .classes.get(recv.name)
        if class_entry.is_some() {
            mut sig = class_entry.unwrap().get("methods").unwrap().get(method)
            if sig.is_some() and sig.unwrap().get("is_static").unwrap_or(false) {
                call.set("dispatch_class", recv.name)
                mut full_args = [object]
                for arg in args { full_args.push(arg) }
                return .type_method_sig(recv.name, recv, sig.unwrap(), full_args, scope, call)
            }
        }
        return .builtin_method(recv, method, args, scope)
    }
```

- [ ] **Step 2: Verify the compiler still self-hosts**

```
make selfhost
```

Expected: byte-exact fixpoint. The change is in the type checker source — self-hosting runs the existing binary to compile the new source, so this tests that the new source is valid Lazarus.

- [ ] **Step 3: Commit**

```bash
git add compiler/frontend/typecheck/Typecheck.laz bin/lazarusc.lua
git commit -m "feat(typecheck): dispatch HOF calls on built-in types to static class methods"
```

---

## Task 4: Emitter dispatch

**Files:**
- Modify: `compiler/backend/ExprEmitter.laz`

### Context

`emit_call` (line 226) currently handles method calls on built-in types via `ExprEmitter.builtins` (a static map of method name → `__lz_*` helper). HOF names (`map`, `filter`, etc.) are NOT in that table. When the type checker sets `dispatch_class` on a call node, the emitter must use that to emit `List.map(receiver, args...)` instead of the fallthrough (`receiver:method(args)` which would crash since list tagged-tables have no `map` field).

### The relevant section of `emit_call` (around line 246)

```laz
        mut helper = ExprEmitter.builtins.get(field)
        if helper.is_some() {
            .ctx.mark_collections()
            return helper.unwrap() ++ "(" ++ Text.join(.with_receiver(object, args), ", ") ++ ")"
        }
    }
    // ... falls through to other cases
```

### What to add right after the `builtins` check

```laz
        mut dispatch_cls = node.attr("dispatch_class")
        if dispatch_cls.is_some() {
            .ctx.mark_collections()
            return dispatch_cls.unwrap() ++ "." ++ field ++ "(" ++ Text.join(.with_receiver(object, args), ", ") ++ ")"
        }
```

- [ ] **Step 1: Apply the change to `compiler/backend/ExprEmitter.laz`**

Find `emit_call` (line 226). After the `builtins` block (around line 251), inside the first `if callee.kind == "MemberExpr"` block, add the `dispatch_class` check:

```laz
        // existing builtins check:
        mut helper = ExprEmitter.builtins.get(field)
        if helper.is_some() {
            .ctx.mark_collections()
            return helper.unwrap() ++ "(" ++ Text.join(.with_receiver(object, args), ", ") ++ ")"
        }
        // NEW: compile-time dispatch for HOF on built-in types
        mut dispatch_cls = node.attr("dispatch_class")
        if dispatch_cls.is_some() {
            .ctx.mark_collections()
            return dispatch_cls.unwrap() ++ "." ++ field ++ "(" ++ Text.join(.with_receiver(object, args), ", ") ++ ")"
        }
    }
```

- [ ] **Step 2: Verify the compiler still self-hosts**

```
make selfhost
```

- [ ] **Step 3: Commit**

```bash
git add compiler/backend/ExprEmitter.laz bin/lazarusc.lua
git commit -m "feat(emitter): use dispatch_class annotation to rewrite HOF calls to static dispatch"
```

---

## Task 5: Integration test

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
    doubled = nums.map(fn(x: int): int { return x * 2 })
    if doubled.get(0).unwrap() != 2 { Sys.panic("map[0]") }
    if doubled.get(2).unwrap() != 6 { Sys.panic("map[2]") }
    if doubled.len() != 5 { Sys.panic("map len") }

    // filter
    evens = nums.filter(fn(x: int): bool { return x % 2 == 0 })
    if evens.len() != 2 { Sys.panic("filter len") }
    if evens.get(0).unwrap() != 2 { Sys.panic("filter[0]") }
    if evens.get(1).unwrap() != 4 { Sys.panic("filter[1]") }

    // fold
    sum = nums.fold(0, fn(acc: int, x: int): int { return acc + x })
    if sum != 15 { Sys.panic("fold sum") }

    // any
    if !nums.any(fn(x: int): bool { return x > 4 }) { Sys.panic("any true") }
    if nums.any(fn(x: int): bool { return x > 10 }) { Sys.panic("any false") }

    // all
    if !nums.all(fn(x: int): bool { return x > 0 }) { Sys.panic("all true") }
    if nums.all(fn(x: int): bool { return x > 3 }) { Sys.panic("all false") }

    // find
    found = nums.find(fn(x: int): bool { return x > 3 })
    if !found.is_some() { Sys.panic("find some") }
    if found.unwrap() != 4 { Sys.panic("find value") }
    missing = nums.find(fn(x: int): bool { return x > 99 })
    if !missing.is_none() { Sys.panic("find none") }

    // chaining: map then filter
    big_doubled = nums.map(fn(x: int): int { return x * 2 }).filter(fn(x: int): bool { return x > 6 })
    if big_doubled.len() != 2 { Sys.panic("chain len") }
    if big_doubled.get(0).unwrap() != 8 { Sys.panic("chain[0]") }

    // ---- Map HOF ----
    scores: Map<str, int> = ["alice": 10, "bob": 5]

    // map
    doubled_scores = scores.map(fn(k: str, v: int): int { return v * 2 })
    if doubled_scores.get("alice").unwrap() != 20 { Sys.panic("map.map alice") }
    if doubled_scores.get("bob").unwrap() != 10 { Sys.panic("map.map bob") }

    // filter
    high = scores.filter(fn(k: str, v: int): bool { return v > 7 })
    if !high.has("alice") { Sys.panic("filter has alice") }
    if high.has("bob") { Sys.panic("filter no bob") }

    // fold
    total = scores.fold(0, fn(acc: int, k: str, v: int): int { return acc + v })
    if total != 15 { Sys.panic("map.fold total") }

    // any
    if !scores.any(fn(k: str, v: int): bool { return v > 9 }) { Sys.panic("map.any true") }
    if scores.any(fn(k: str, v: int): bool { return v > 99 }) { Sys.panic("map.any false") }

    // all
    if !scores.all(fn(k: str, v: int): bool { return v > 0 }) { Sys.panic("map.all true") }
    if scores.all(fn(k: str, v: int): bool { return v > 9 }) { Sys.panic("map.all false") }

    // find
    top = scores.find(fn(k: str, v: int): bool { return v > 9 })
    if !top.is_some() { Sys.panic("map.find some") }
    if top.unwrap() != 10 { Sys.panic("map.find value") }

    Sys.print("collection HOF: all assertions passed")
}
```

- [ ] **Step 2: Compile**

```
lua bin/lazarusc.lua examples/CollectionHOF.laz
```

Expected: no type errors. `Main.lua` written. If any TypeError appears, it points to which compiler change needs fixing.

- [ ] **Step 3: Run**

```
lua Main.lua
```

Expected:
```
collection HOF: all assertions passed
```

Any `Sys.panic` message tells you exactly which case failed.

- [ ] **Step 4: Commit**

```bash
git add examples/CollectionHOF.laz
git commit -m "test(examples): CollectionHOF — integration test for List/Map HOF with xs.map(f) syntax"
```

---

## Task 6: Selfhost fixpoint

- [ ] **Step 1: Run**

```
make selfhost
```

Expected: stage1 == stage2 byte-exact. Binary installed.

- [ ] **Step 2: Commit regenerated binary if changed**

```bash
git add bin/lazarusc.lua
git commit -m "chore: regenerate bin/lazarusc.lua"
```

---

## Troubleshooting

**TypeError "wrong number of arguments" on `xs.map(f)`** — `full_args` must be `[object, ...args]` (receiver prepended). Check that the receiver node is correctly built in `type_method_call`.

**TypeError "no method 'map' on List"** — The `dispatch_class` lookup ran but returned none. Check that `std.List` is actually imported in the test file AND that `collect_signatures` ran for it (the module must not be `is_interface`).

**Emitter produces `xs:map(f)` instead of `List.map(xs, f)`** — `dispatch_class` annotation not set (type checker change missing or not reaching the right branch). Add a print to debug.

**Chaining fails** — `xs.map(f)` returns a plain `List<U>` value. The `.filter(g)` call on it should resolve through the same dispatch mechanism since the return type is still `List<U>` (a built-in type). Verify the return type of `type_method_sig` is correct.

**`make selfhost` fails after type checker change** — The compiler source uses `node.set(...)` and `node.attr(...)` already. The change adds one `call.set("dispatch_class", ...)` call — valid Lazarus. If it fails, check syntax around the new block.
