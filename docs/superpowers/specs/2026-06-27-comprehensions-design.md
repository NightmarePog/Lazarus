# L2 — For-loop comprehensions (design spec)

Date: 2026-06-27
Status: approved direction, implementing

## Goal

Collapse the dominant `mut out = []; for x in xs { out.push(f(x)) }` pattern
(~85 in the compiler) into expressions:

```laz
mut squares = [x * x for x in xs]
mut evens   = [x for x in xs if x % 2 == 0]
mut keyed   = [k: f(v) for k, v in m]        // map comprehension
mut pairs   = [v for k, v in m]              // two loop vars over a map
```

No closures required — it is compile-time sugar.

## Syntax

Inside `[...]`, after the first expression:
- a `for` ⇒ **list comprehension** (`[elem for vars in iter (if cond)]`);
- a `:` then a value then `for` ⇒ **map comprehension** (`[key: value for vars in
  iter (if cond)]`);
- otherwise the existing list/map literal.

The clause: `for <var> [, <var2>] in <iter> [if <cond>]`. One var over a `List`
binds the element; two vars over a `Map` bind key, value (same as `for-in`).

## AST

- `ListComp`: `element`, `vars` (names), `iter`, optional `cond`.
- `MapComp`: `key`, `value`, `vars`, `iter`, optional `cond`.

## Lowering (ExprEmitter → IIFE)

A comprehension is an expression, so it lowers to an immediately-invoked Lua
function that builds and returns the collection, reusing the existing `__lz_each`
iteration and `__lz_push` / `__lz_idx_set` helpers:

```lua
-- [elem for x in xs if cond]
(function() local T = __lz_list() for _, x in __lz_each(XS) do if COND then __lz_push(T, ELEM) end end return T end)()

-- [k: v for k, v in m]
(function() local T = __lz_map({}) for k, v in __lz_each(M) do __lz_idx_set(T, K, V) end return T end)()
```

`T` is a fresh temp; loop vars are declared as locals in a pushed scope so the
element/key/value/cond emit as bare names. The IIFE closes over `self`, so
`[.f(x) for x in xs]` works. `mark_collections()` pulls in the prelude.

## Per-pass changes (all expression-side)

- **ExprParser** — detect comprehensions in `parse_collection`; parse the clause.
- **ExprChecker** — check `iter` in the outer scope; declare loop vars
  (`Symbol("variable", false, false)`) in a child scope; check element/key/value
  there; `cond` via `check_condition` (must be boolean). (Mandatory — otherwise the
  loop var reads as an undeclared identifier.)
- **Typecheck** — `iter` typed, `bind_loop_vars` binds the vars, then the element
  type `E` ⇒ `List<E>` (key/value ⇒ `Map<K,V>`). Reuses `bind_loop_vars`.
- **ExprFolder** — fold `iter` (outer) and element/key/value/cond in a constant
  scope that shadows the loop vars (mirrors `fold_for_in`).
- **ExprEmitter** — emit the IIFE above.

All five dispatchers already use `match` with a `_` default, so adding arms is
clean. No runtime/linker changes.

## Testing

1. `[x*x for x in [1,2,3]]` → `[1,4,9]`.
2. filter: `[x for x in [1,2,3,4] if x % 2 == 0]` → `[2,4]`.
3. map comp: `[k: v*2 for k, v in ["a":1,"b":2]]` values doubled.
4. two vars over a map: `[v for k, v in m]`.
5. nested element call closing over `self`: `[.bump(x) for x in xs]`.
6. typed: `mut o: List<int> = [x for x in xs]` ok; element-type mismatch flagged.
7. loop var undeclared-leak: referencing the var outside the comprehension errors.
8. self-host fixpoint holds.
9. (Optional) rewrite a few compiler loops as comprehensions; fixpoint holds.
