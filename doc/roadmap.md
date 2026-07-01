# Lazarus — Roadmap & Planned Features

Status snapshot and the agreed backlog. Captures the planning discussion of
2026-06-27. For the deeper v2 language spec see [`doc/design/`](design/); for the
typing history see [`doc/self-hosting/TYPING-ROADMAP.md`](self-hosting/TYPING-ROADMAP.md).

## Where v1 is now (shipped)

- **Self-hosting compiler** — 3-stage byte-exact fixpoint (`bin/build-compiler`).
- **Gradual static typing** — `int`/`float`/`bool`/`str`/`unit`/`dynamic`; checked,
  then erased. Unannotated code stays dynamic (lenient inference).
- **Classes** — file = class; lower to **plain Lua tables, no metatables** (methods
  copied onto instances) for speed. Constructor dependency injection (manual).
- **Generics** — generic classes, enums, methods; type erasure.
- **Enums** — bare variants, payloads, `match` exhaustiveness.
- **`match`** — value and enum-variant patterns; now used throughout the compiler.
- **Built-ins** — `List<T>`/`Map<K,V>`/`Option<T>`/`Result<T>` as fast tagged tables
  with intrinsic typing (no std files, no method-dispatch cost).
- **Structural interfaces** — generic, interface-directed structural subtyping,
  fully erased. Inline `interface` and `#interface` files. (Shipped 2026-06-27.)
- **`#kind` file directives** — `#interface`, `#object` (static modules). Extensible.
- **Interop** — `extern` FFI to Lua; path-based module imports from the project root.
- **Backend** — emits Lua 5.1; constant-folding optimizer.

## Planned features (the backlog)

Ordered roughly by value ÷ risk. One issue per part; each gets a design pass and a
fixpoint check before the next.

### Language features

| # | Feature | Size / risk | Notes |
|---|---------|-------------|-------|
| **L1** | **Constructor param-properties** — `constructor(.cursor, .exprs)` declares + assigns the field in one stroke | Small, low risk | Kills the pervasive DI boilerplate (`private x` + `.x = x`). Fits the `.field` model. Parser + codegen only, no runtime cost. **Recommended first.** |
| **L2** | **For-loop comprehensions** — `[f(x) for x in xs]`, `[x for x in xs if cond]`, `[k: f(v) for k, v in m]` | Medium, low risk | Pure compile-time sugar lowering to today's loops. **No closures needed.** Collapses ~85 map/filter loops measured in the compiler. |
| **L3** | **Annotations / decorators** — `@name` on declarations | Medium | Composes with the `#kind` directive. Decide scope: *annotations* (readable metadata, e.g. `@deprecated`, `@test`) vs *decorators* (transform the decl — needs closures or AST transforms). |
| **L4** | **Getters / setters** — computed properties | Medium, **design tension** | Collides with the no-metatables model: `obj.field` is a raw table read a getter can't intercept. Needs a decision first: compile-time access rewriting (typed call sites only) vs metatables for accessor classes (a perf cost). |
| **L5** | **Macros** | Largest — defer | Deep design space (syntactic vs AST vs hygienic). A project unto itself; do last, if at all. |

### Backend / targets

| # | Feature | Notes |
|---|---------|-------|
| **B1** | **Multi-version / platform codegen** — Lua 5.1 / 5.2 / 5.3, **ComputerCraft / OpenComputers** | A `--target` system: the codegen and the `__lz_*` runtime prelude adapt per target (5.3 integers & `//`, `table.unpack` vs `unpack`, no `setfenv` in 5.2+…), plus platform stdlib/externs (CC `term`, OC `component`). Mostly additive in `Runtime`/`Codegen`. Pairs with B2. |
| **B2** | **Native backend (C, then optionally LLVM)** — exploratory | Emit C (clang/gcc → native) from the **typed IR**, with a small runtime + GC. The frontend + type system are the reusable, done part; the project's center of gravity is **a runtime with garbage collection**, not the codegen. Key blockers: a memory/GC model, and `dynamic` (needs a boxed fallback or fully-typed code). NB: going `Lazarus → Lua → C` **erases the types** that make native compilation worthwhile — emit C straight from the typed IR. For a free standalone binary today, `luastatic` bundles the Lua VM; for free speed, run output under **LuaJIT**. |

### Tooling (separate programs that reuse the frontend; do not change the language)

| # | Feature | Notes |
|---|---------|-------|
| **T1** | **Documentation generator** | Walk the AST, keep `public` declarations, emit Markdown with typed signatures + the leading `//` doc comments. Non-invasive comment capture: pair contiguous `//` blocks with each node's `line`/`col` — **no lexer/parser change**. Replaces the dead Doxygen setup (`doc/Doxyfile`, which has no Lazarus parser). Higher with the new typing/interfaces. |
| **T2** | **LSP server** | Wrap the existing lexer/parser/checker, speak JSON-RPC over stdio: diagnostics first, then hover / go-to-def / completion. Big but additive; the frontend already produces what it needs. |
| **T3** | **Package manager** | Manifest + dependency resolver for lib importing. Scope small first: a manifest + local/path deps + resolver. Mostly tooling outside the compiler; pairs with B1. |

**Shared infrastructure:** T1 and T2 both "wrap the frontend and read declarations" —
build a single **declaration-extraction** layer and let docs + LSP consume it.

## v1 gaps → what v2 should add

What v1 deliberately or pragmatically left out, and the v2 direction:

| Gap in v1 | Impact | v2 direction |
|-----------|--------|--------------|
| **First-class functions / closures / lambdas** | Biggest gap. Blocks `map`/`filter`/`reduce`, callbacks, higher-order code, function-style decorators. Comprehensions (L2) sidestep it for the common case. | Add function values + closures. Unlocks collection methods and decorator functions. |
| **Inheritance / nominal subtyping** | No class hierarchies; `super`/overriding absent. Structural **interfaces** already cover the contract/polymorphism half. | Decide: full inheritance vs compose-only + interfaces. Covariant interface returns already anticipate a subtype relation. |
| **Getters / setters** | Computed properties must be methods. | L4 — needs the metatables-vs-rewrite decision. |
| **Constructor boilerplate** | Every stateful class repeats field-decl + assignment. | L1 — param-properties. |
| **Repetitive `for` loops** | ~85 map/filter-shaped loops. | L2 comprehensions now; collection methods once closures land. |
| **Metaprogramming** | No macros/decorators. | L3 annotations, then L5 macros. |
| **Single backend / runtime** | Lua 5.1 only. | B1 multi-target; B2 native. |
| **No ecosystem tooling** | No package manager, LSP, or doc generator. | T1/T2/T3. |
| **Binary visibility only** | `private`/`public`; no module/package scoping. | Revisit with the package manager (T3). |

### Suggested overall sequence

`L1 → L2 → L3 → T1 → B1 → L4 → T2 → T3 → B2 → L5`

(Boilerplate and loop wins first; docs early since they're cheap and compound;
metatables/native/macros and the heavy tooling later. Closures are the cross-cutting
unlock that makes L3-as-decorators, collection methods, and more land cleanly — worth
scheduling explicitly once L1/L2 are in.)
