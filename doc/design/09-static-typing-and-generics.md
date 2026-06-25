# 09 — Static Typing & Generics (design spec)

**Status:** proposal for sign-off. No code yet. Supersedes the "no user
generics" stance of `04-types-and-data.md` once accepted.

This spec is written to your four answers:

1. **Gradual**, with a twist: **function parameters and return types are
   mandatorily typed**; ordinary `mut`/field **declarations may stay dynamic**.
2. **Full inference** everywhere it isn't mandatory-explicit (so: explicit
   signatures, inferred bodies/locals/fields).
3. **Full user generics** on **both classes and enums**.
4. Types are **erased** (compile-time only, zero runtime cost) — my one stated
   assumption.

---

## 0. Decisions (signed off 2026-06-25)

- **D1 — Rollout = annotate everything first.** End state is a **fully-typed**
  `compiler/`, with the mandatory-signature rule **strict** (no permanent
  gradual/transitional-dynamic mode). `dynamic` remains a real type for genuinely
  dynamic data, but is *not* a way to leave a function untyped long-term.
  *Implementation reality:* the checker is staged so each `make selfhost` keeps
  passing — it tolerates not-yet-annotated functions **only during the
  annotation phase**, then enforcement is switched on. The build is "blocked" on
  finishing annotation in the sense that the milestone isn't done until every
  function in `compiler/` is typed.
- **D2 — `Option`/`Result` = generic enums.**
  `enum Option<T> { Some(T), None }`, `enum Result<T> { Ok(T), Err(str) }`.
  Requires **payload-carrying enum variants** first (deferred in Phase 2a, §7).
- **D3 — Finish `float` now.** `float` is a first-class distinct type with real
  arithmetic, division (`/`), modulo/power as applicable, and explicit
  `int`↔`float` conversion. Folds into the optimizer/codegen as part of this work
  (no longer deferred).

---

## 1. Goals & non-goals

**Goals.** Catch type errors at compile time; make signatures the contract
(killing the comments that hand-carry param/return shapes); replace the six
`OptionInt/…/ResultBool` stdlib copies with one `Option<T>` + one `Result<T>`.

**Non-goals (this round).** No subtyping/inheritance (the language has none). No
type-classes/traits/bounds on generics (type params are unconstrained). No
higher-kinded types. No reflection. No runtime type info.

---

## 2. The type lattice

Types are compile-time values (represented like the AST: a tag + fields, since
the language has no inheritance):

| Type | Surface | Notes |
|---|---|---|
| `int` `float` `bool` `str` | same | primitives; `int`/`float` distinct, no implicit convert |
| `dynamic` | `dynamic` (or absent on a decl) | the gradual escape hatch / "any" |
| function | `(T1, T2) -> R` | params + return; first-class types only (no first-class *values* yet) |
| class | `ClassName` | nominal; from a `class`/file |
| enum | `EnumName` | nominal; from an `enum` |
| generic instance | `Name<A, B>` | a class/enum applied to type args |
| type variable | `T` | only inside a generic decl's scope |

`dynamic` is the top of the gradual lattice: anything flows into `dynamic` and
`dynamic` flows into anything (unchecked — see §4.3). There is **no `nil`/null**;
absence is `Option<T>`.

---

## 3. Surface syntax

Annotations are postfix `: Type`, consistent with the design doc.

```
// functions — params and return MANDATORY (rule #1)
greet(name: str): str { return "hi " ++ name }
area(self, r: int): int { return r * r }
log(msg: str): unit { Sys.print(msg) }     // `unit` = returns nothing

// declarations — type OPTIONAL (inferred, may stay dynamic)
mut n = 5            // inferred int
mut t: str = read()  // explicit
private count: int   // field annotation
private cache         // dynamic field (allowed)

// generics — type params in angle brackets on the declaration
enum Option<T> { Some(T), None }
enum Result<T> { Ok(T), Err(str) }
class Box<T> { private value: T  constructor(v: T) { .value = v }  get(): T { return .value } }

// type-expression grammar
Type    := 'dynamic' | 'unit' | prim | Name ('<' Type (',' Type)* '>')? | '(' Type,* ')' '->' Type
```

`unit` is the no-value return type (erases to a Lua function returning nothing).
A function with no `: Type` return is an **error** under rule #1 (unless it's a
fully-unannotated transitional-dynamic function, D1a) — write `: unit` explicitly.

---

## 4. Checking & inference

### 4.1 Where it runs
A **new pass, `Typecheck`, after `Schematic`** (which already did
name-resolution, scopes, instance-member collection). Typecheck reuses that
scope info, walks the AST bottom-up, and annotates each expression with a type
for the next expression up. Erased → **codegen is unchanged**.

### 4.2 Inference (bidirectional, not whole-program HM)
Because signatures are explicit, "full inference" collapses to a tractable
bottom-up scheme — no Hindley-Milner needed:
- **Expressions** synthesize a type bottom-up (literal → its prim; `a + b` →
  numeric rules; call → callee's return type; `.field` → field type; etc.).
- **Locals** (`mut x = e`) take `e`'s synthesized type. Reassignment must be
  compatible.
- **Fields** take the type of their declared annotation, else the type assigned
  in the constructor (synthesized).
- **Generic type args** are inferred by **unification at the use site**:
  `Result.ok(5)` unifies the param type `T` against `int`, giving `Result<int>`.
- **`match`** over an enum: each arm's payload binding gets the variant's field
  type; exhaustiveness already exists (Phase 2a).

### 4.3 The gradual boundary (soundness note)
`dynamic` is contagious and **unchecked**: a `dynamic` value may be passed where
any type is expected and vice-versa, with no runtime check (types are erased).
This is deliberately unsound at the boundary — same model as TypeScript `any`.
Mandatory signatures keep the *typed* core sound; `dynamic` is the explicit
escape used by transitional code and genuinely dynamic data.

---

## 5. Equality / assignability rules
- Primitives: identical only. `int` ≠ `float` (convert via a future `to_float`).
- Nominal: same class/enum name; generic instances equal iff same constructor
  **and** equal type args (`Result<int>` ≠ `Result<str>`).
- `dynamic` assignable to/from anything.
- `unit` only where no value is used.

---

## 6. Generics

- **Declaration:** `<T, U, …>` after the class/enum name introduces type
  variables in scope for that declaration's fields, variants, and method
  signatures.
- **Use:** `Name<Arg, …>`; arity-checked. Bare `Name` for a generic type is an
  error (no implicit args) **except** where inference supplies them (a
  constructor/factory call).
- **Erasure:** type args are dropped after checking. `Box<int>` and `Box<str>`
  share one emitted `Box` table; `Result<T>` emits exactly today's tagged-table
  code. **No monomorphization, no runtime tags.**
- **Generic methods** (a method with its own `<T>`): out of scope this round
  unless you want them — say so.

---

## 7. `Option<T>` / `Result<T>` and the std migration

Target end state (D2 = generic enums):
```
enum Option<T> { Some(T), None }
enum Result<T> { Ok(T), Err(str) }
```
with methods (`is_some`, `unwrap`, `take`, `map`, …) — as generic enum methods,
or as free functions, TBD with you.

**Prerequisite:** payload-carrying enum variants (`Some(T)`, `Ok(T)`), which
Phase 2a explicitly deferred. So the order is: payload variants → generics →
rewrite std. Then **delete** `OptionInt/OptionString/OptionBool/ResultInt/
ResultString/ResultBool` and repoint imports to `Option`/`Result`.

Method surface (`is_some`, `unwrap`/`take`, `unwrap_or`/`take_or`, `map`, …) is
TBD with you when we reach phase 8 — as generic enum methods or free functions.

---

## 8. Erasure / codegen
No change. Typecheck is a pure analysis pass; the backend emits exactly what it
does today. A program that type-checks produces identical Lua to the untyped
version. This is what keeps the self-host fixpoint intact through the transition.

---

## 9. Phasing (each phase: implement in old syntax → `make selfhost` → verify)

1. **Type syntax + representation**: parse `: Type`, `<T>`, type expressions, and
   `unit` into the AST; the `Type` value model. No checking yet
   (parse-and-ignore), so the untyped self-host keeps building.
2. **`float`** (D3): distinct `float` type, literals, arithmetic/division/modulo,
   `int`↔`float` conversion, optimizer + codegen support.
3. **Payload-carrying enum variants** (`Some(T)`/`Ok(T)`): finishes deferred
   Phase 2a; needed before generic enums.
4. **Core checker (monomorphic)**: primitives + `float`, functions, classes,
   enums, `dynamic`, local/field inference, the gradual boundary. Lenient toward
   not-yet-annotated functions *during* phase 6 only.
5. **Generics**: type params on classes/enums, instantiation, type-arg inference
   by unification, erasure.
6. **Annotate `compiler/` (D1)**: type every function in the self-host, file by
   file (`make selfhost` + `busted` after each). This is what deletes the
   param/return-shape comments — the original goal.
7. **Enforce strict** (D1): flip mandatory-signature checking on; a missing
   signature is now an error.
8. **std rewrite (D2)**: `Option<T>` + `Result<T>` as generic enums; delete
   `OptionInt/OptionString/OptionBool/ResultInt/ResultString/ResultBool`; repoint
   imports.

---

## 10. Risks
- **Bootstrap:** all new syntax (`:`, `<>`) goes in via the ladder
  (`bin/lazarusc.lua` seed → `make selfhost`); `compiler/` source doesn't *use*
  it until step 6, so the self-host keeps building throughout.
- **Annotation phase is large (D1):** typing ~35 files is the long pole. Done
  file-by-file with `make selfhost` + `busted` after each, so regressions stay
  local. The checker stays lenient until that phase completes, then strict.
- **Inference scope creep:** keeping it bottom-up + unification (not HM) is the
  guardrail; whole-program inference is explicitly out.
