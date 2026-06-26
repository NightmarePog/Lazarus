# Types 5 — generics (enums + classes, inference, erasure) — design

**Issue:** #12 · **Part:** 2 of 5 (4b ✓ → **5** → 6 → 7 → 8) · **Branch:** `feat/types-5-generics` (off `main`)
**Roadmap:** `doc/self-hosting/TYPING-ROADMAP.md` · **Full design:** `doc/design/09-static-typing-and-generics.md`

## Goal

Make type variables real. Generic enums and classes declare type params; the
checker infers type args at use sites by unification, checks concrete arg
clashes, and erases everything (codegen unchanged). Directly unblocks Part 5
(#15): one `Option<T>` + one `Result<T>` replacing the six hand-copied stdlib
types.

## Locked decisions

| Area | Decision |
|------|----------|
| Scope | Generics on **enums and classes**, plus **generic methods**. |
| Class type params | Declared on the constructor: `constructor<T, U>(...)`; scope the whole file-class. |
| Generic methods | A method may carry its own `<U>` with its own inference scope. **Limited to non-function signatures this round** — methods that *take* a function (`map`/`fold`) await first-class function values, a separate next part. |
| Enum variant construction | **Bare**: `Some(5)`, `None`, `Ok("hi")` — prelude-style, resolved via the program-wide variant registry. |
| Leniency | **Fully lenient** about missing/unsolvable args: bare `Option` = `Option<dynamic>`; unsolved inference → `dynamic`. Only two **concrete** args clash (`Result<int>` ≠ `Result<str>`). |
| Explicit-arg arity | When args ARE written (`Option<int, str>`), the count must match the decl — else error. Bare (no `<...>`) is always allowed. |
| Erasure | Type args dropped after checking; runtime is plain Lua. No monomorphization, no runtime tags. |

## Surface syntax

```
// std/Option.laz                 // std/Result.laz
enum Option<T> { Some(T), None }  enum Result<T> { Ok(T), Err(str) }

mut a = Some(5)     // a : Option<int>      (inferred, then erased)
mut b = None        // b : Option<dynamic>
mut r = Ok("hi")    // r : Result<str>
match a { Some(v) => { print(v) }  None => { } }   // v : int

// generic class — type params on the constructor (Pair.laz)
constructor<A, B>(a: A, b: B) { .left = a  .right = b }
first(): A { return .left }
mut p = Pair(1, "x")   // p : Pair<int, str>
mut f = p.first()      // f : int

// generic method — its own <U> (parsing/scoping/inference land now)
wrap<U>(u: U): Pair<A, U> { ... }    // p.wrap("z") : Pair<int, str>

// DEFERRED to the function-values part: a method that TAKES a function needs
// first-class function values, which don't exist yet.
//   map<U>(fn: (A) -> U): U { return fn(.left) }
```

## Out of scope (deferred)

- **First-class function values** (lambdas / passing & calling functions): the
  *next* part. Until it lands, generic methods may not take function-value
  params, so `map`/`fold`-style methods are deferred. Everything else generic
  (enum/class generics, bare variants, non-function generic methods) ships here.

## Architecture

### 1. Parser
- `parse_constructor`: call `parse_type_params()` (already exists; only consumes on `<`) before `(`; store as `type_params` on `constructor_decl` (the class's type params).
- `parse_method`: same between the method name and `(`; store on `function_decl`.
- Extend `Ast.constructor_decl` / `Ast.function_decl` to carry `type_params`.
- Enum header `enum E<T>` and type-args `Name<A,B>` already parse — no change.
- Backward-compatible: no `<` → empty params. `compiler/` source uses no
  generics, so `make selfhost` stays valid.

### 2. Type model (`compiler/frontend/typecheck/Type.laz`)
- New `var` kind: `Type.var(name)` — a type variable.
- `class`/`enum` types reuse the existing `params` list to hold **type args**:
  `Option<int>` = `enum "Option"` with `params=[int]`; non-generic = `params=[]`.
- `class_of(name, args)` / `enum_of(name, args)` gain an args param; existing 4b
  call sites pass `[]`. `SelfExpr` resolves to `class_of(class_name, [var(p) …])`
  (the class's own params as vars), so members typed in `T` flow.

### 3. Type-var scoping (`resolve`)
A `.type_vars` map holds names in scope. Set to the **class's** params at
`check()`. A generic method merges its own `<U>` for its signature + body, then
restores (methods don't nest → set/reset, no stack). `resolve("T")` → `var("T")`
when in scope (checked before enum/class lookup). Resolving a **callee's**
annotation uses the callee's param set via `resolve_with(node, vars)` (swap
`.type_vars` around the resolution), since a class's `T` is meaningless in the
caller's module.

### 4. Registry (`Main`)
- `collect_signatures`: record each class's `type_params` (from its
  `constructor<…>`) and each method's own `type_params`.
- `collect_enums`: record `enum_type_params[E]` (variant field nodes already in
  `variant_fields`).
- Thread `enum_type_params` (+ class/method params already inside `classes`) into
  `Typecheck`.

### 5. Instantiation + arity
In `resolve`, `Name<Args>` → `class_of/enum_of(name, resolvedArgs)`. If args are
explicitly written, arity-check against the declared count (wrong count errors).
Bare `Name` → `params=[]` (lenient).

### 6. Inference — `unify` + `substitute`
At construction `Pair(args)`, bare variant `Some(args)`, and method calls:
resolve the callee's declared param types **in the callee's var scope** (so they
contain `var`s), **unify** them against the synthesized arg types into a
substitution `{T: int}`, then **substitute** into the nominal → `Pair<int,str>`,
`Option<int>`. A method returning `T` on a `Box<int>` receiver substitutes via
the receiver's args → `int`. `unify` never fails (lenient) — it only solves
vars; first binding wins; unbound → `dynamic`. Concrete arg type-checking still
runs via `expect` after substitution.

```
unify(param, arg, subst):
  param is var      -> bind subst[param.name]=arg if unbound
  param|arg dynamic -> (no constraint)
  same class/enum   -> unify args pairwise
  else              -> (nothing to solve)

substitute(t, subst):
  var          -> subst[t.name] or dynamic
  fn           -> recurse params + result
  class/enum   -> substitute each arg
  else         -> t
```

### 7. Bare variant construction (the chosen syntax)
- **Schematic / `ExprChecker`:** a bare identifier or call whose name is a known
  variant (`variant_owner.has(name)`) is valid — payload variants callable
  (arity checked via `variant_arity`), nullary variants are values. Works
  program-wide (prelude-style), no import required.
- **Codegen / `ExprEmitter`:** rewrite a bare variant reference to its
  owner-qualified emitted form — `Some(5)` → `Option.Some(5)`, `None` →
  `Option.None` — using `variant_owner`.
- **Typecheck:** bare `Some(args)` (callee is a known variant) → variant
  construction inference (§6) → `enum_of(owner, solvedArgs)`; bare nullary `None`
  → `enum_of(owner, [dynamic …])`. Match arms stay bare (already work).

### 8. Compatibility (lenient args)
`compatible`: `dynamic` or unsolved `var` either side → ok. Else name/kind must
match, then args compared position-wise where a missing/`dynamic` arg is
compatible — so `Result<int>` vs `Result<str>` clashes, `Result` vs `Result<int>`
is fine. (`equals` stays name-only for class/enum; arg leniency lives in
`compatible`/`args_compatible`.)

### 9. Erasure
Codegen ignores `type_params` and type args entirely (verified: backend
references none of `type_params`/`param_types`/`return_type`). `Some(5)` lowers
to `{kind="Some", _1=5}` via the bare-variant rewrite. Nothing else to do.

## Testing & guardrails

- `make selfhost` fixpoint holds (compiler source stays non-generic).
- New typed `.laz` programs (run through `bin/lazarusc.lua`):
  - generic enum: `Some(5)` → `Option<int>`; payload flows through `match` (`v : int`).
  - generic class via `constructor<T>`: field/method `T` flow; `Pair(1,"x").first() : int`.
  - generic method `<U>`.
  - clash: `Result<int>` where `Result<str>` expected → error.
  - bare `Option` annotation accepted (= `Option<dynamic>`).
  - wrong explicit arity `Option<int,str>` → error.
  - bare variant construction compiles AND runs (codegen rewrite correct).

## Risks

- Inference touches many sites (construction, bare variant ctor, method call,
  member) — staged, each validated by a probe program.
- Bare variant construction adds Schematic + codegen work, not just typecheck —
  the larger surface of this part. Confirm the bare-variant emit against
  `ExprEmitter` as the first impl step.
- `.type_vars` field swapping must restore correctly around generic methods and
  callee resolution — covered by nested-generic-call tests.

## Definition of done

- `constructor<T>` / method `<U>` parse; registries carry class/method/enum params.
- `var` kind + generic-instance args in the Type model; `resolve` makes vars real
  in scope; instantiation arity-checked on explicit args.
- `unify`/`substitute` infer type args at construction, bare variant, and method
  sites; method returns substitute via receiver args.
- Bare variant construction resolves (Schematic), lowers (codegen), and infers
  (typecheck); match arms unaffected.
- Lenient compatibility: concrete arg clashes bite, missing/unknown args don't.
- `make selfhost` fixpoint green; all probe programs pass.
