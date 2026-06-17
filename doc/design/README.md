# Lazarus v1 — Language Design

This folder is the design specification for the next major version of Lazarus: a
small, statically-typed, class-oriented language that compiles to a single
self-contained Lua file. It is the agreed result of a detailed design pass; the
documents here describe **what** the language is and **how** each feature lowers
through the existing compiler pipeline (Lexer → Parser → Schematic → Optimizer →
Codegen, see [`../pipeline.md`](../pipeline.md)).

> Status: **design draft.** Nothing here is implemented yet. The current
> compiler supports only a procedural subset (`pub`/`mut` bindings, `fn`,
> `return`, `+ - *`, calls). These documents define the target to build toward,
> feature by feature, using the recipe in [`../adding-features.md`](../adding-features.md).

## Documents

| File | Covers |
|---|---|
| [01-overview.md](01-overview.md) | Vision, the "file = class" model, a complete example, target runtime |
| [02-lexical.md](02-lexical.md) | Comments, identifiers & casing, literals, operators, bindings, visibility |
| [03-classes.md](03-classes.md) | Fields, `static`, `init`, methods/`self`, inheritance, `override`, abstract, traits |
| [04-types-and-data.md](04-types-and-data.md) | `int`/`float`/`str`/`bool`, `Option`, `Result`, enums, lists/maps, traits, strictness/`as` |
| [05-control-flow.md](05-control-flow.md) | `if`, `while`, `loop`, `for`, `match`, `break` |
| [06-modules-and-linking.md](06-modules-and-linking.md) | `import`/`pub`, libraries, bundling/linking, entry point |
| [07-interop.md](07-interop.md) | `extern`, `lua { }`, `as`, calling CC/OC APIs |
| [08-implementation.md](08-implementation.md) | How everything lowers to Lua 5.0, pipeline impact, build order |

## Decisions log

Every choice below was confirmed during the design pass. Read this as the
single source of truth; the per-topic docs expand on each.

### Foundations
- **File = class.** A file *is* a class; the filename is the class name (must be a
  valid `PascalCase` identifier). No `class` keyword.
- **Classes are the only user type kind** (besides enums). `struct` does **not**
  exist — a class with only fields *is* your data record.
- **Type system:** static, **erased at codegen** (zero runtime type cost).
  **No user generics in v1** — `Option`, `Result`, `[T]`, `{K:V}` are built-in.
- **Linking:** compile-time bundle to **one** self-contained `.lua`. No runtime
  `require`. **No tree-shaking in v1** (imported files linked whole).
- **Target:** **Lua 5.0** now; **Lua 5.4** planned (this is why `int`/`float` are
  distinct even though 5.0 has one number kind).

### Lexical & surface syntax
- **Comments:** `//` line, `/* */` block.
- **Naming is enforced:** types `PascalCase`, functions/variables `snake_case`.
- **Bindings:** bare `x = e` is immutable; `mut x = e` is reassignable. No `let`.
- **Visibility:** `pub` exports an item; everything is private by default.
- **Comparison operators:** `== != < <= > >=`. **Logical:** word forms `and or not`.
- **Arithmetic:** `+ - * / %`, unary `-x`, exponent `^`. `%` is synthesized on 5.0.
- **String concat:** `++` (the `+` operator is numeric-only).
- **Compound assignment:** `+= -= *= /=`.
- **Strings:** double-quoted, escapes (`\n \t \" \\`), interpolation `"hi {name}"`.

### Types & data
- **Numbers:** `int` and `float` are distinct; **no `num` umbrella**.
- **Scalars:** `int`, `float`, `str`, `bool` (with `true`/`false`).
- **No `nil`.** Absence is the built-in `Option<T>` (`Some`/`None`).
- **Errors:** built-in `Result<T, E>` (`Ok`/`Err`), matched explicitly. **No `?`
  operator, no `panic`** — unrecoverable failures drop to `error()` via `lua { }`.
- **Collections:** `[T]` lists and `{K:V}` maps. **0-based** indexing (compiler
  offsets to Lua's 1-based). Length via `.len()`. Methods: `push`, `pop`,
  `get(k): Option`, index assignment.
- **Enums:** declared **inside** a class file. Bare + tuple-payload variants,
  constructed qualified (`State.Idle`), matched with bare patterns. **Data-only**
  (no methods).
- **Traits:** declared with `trait`, implemented by classes via an `impl A, B`
  header. **Compile-time contracts only** (no `dyn`, static dispatch).
- **Strictness:** a strict/loose toggle, **strict by default**. Interop values are
  `any`; in strict mode they must be `as`-asserted (unchecked) before typed use.

### Classes
- **Instance fields:** typed top-level bindings, **immutable by default** (`mut` to
  reassign), **private by default** (`pub` to expose), **defaults allowed**
  (`x: int = 0`).
- **Static members:** a `static { ... }` block for shared state and functions.
- **Constructor:** an `init(params) { ... }` block; construct via `Sprite(3, 4)`.
- **Methods:** instance methods take `self`; called with an **implicit receiver**
  `obj.method()` (lowers to Lua `:`).
- **Inheritance:** single, via `extends Parent`. Overrides require the `override`
  keyword and may call `super.m()`. **Abstract methods** allowed; a class with one
  cannot be instantiated.
- **Self-calls** are bare inside a file; cross-file access is qualified
  (`Counter.bump()`), instances via their constructors/methods.

### Modules & interop
- **Imports are explicit:** `import Vec`, `import Enemy from "actors/Enemy"`; used
  qualified (`Vec.zero()`).
- **No manifest in v1:** `lazarus build src/Main.laz`; imports resolved relative to
  the entry file. (A `lazarus.toml` design is sketched in 06 for later.)
- **Entry point:** the built file's static `fn main()`; the bundler appends a call.
- **Interop:** `extern` declaration blocks (organized in importable stdlib files,
  e.g. `import cc`), plus a raw `lua { }` escape that is expression-valued and
  sees surrounding variables, typed via `as`.

### Deferred to later versions
- Lua 5.4 backend (and the meaningful `int`/`float` runtime split).
- User-defined generics; `dyn` trait objects.
- Tree-shaking / dead-code elimination.
- A `lazarus.toml` manifest and inter-project dependencies.
- `?` error-propagation operator; `continue`.
