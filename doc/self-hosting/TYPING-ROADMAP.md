# Static typing + generics — roadmap & progress

Living checklist for the static-typing effort. Full design: `doc/design/09-static-typing-and-generics.md`.
Per-phase detail also tracked in memory `lazarus-selfhost-compiler-status`.

## Ground rules (every phase)
- Implement in `compiler/` only. `src/` is frozen legacy, not in the build path.
- New syntax via the bootstrap ladder: write it in old syntax → `make selfhost`
  (seeds from `bin/lazarusc.lua`, verifies the stage1==stage2 fixpoint, installs)
  → then the binary understands it. Commit the refreshed `bin/lazarusc.lua` with
  the source.
- After each phase: `make selfhost` (fixpoint) **and** `busted` (must stay 394/0),
  plus a typed test program exercising the new behaviour.
- Decisions locked: gradual surface but **strict end state** (annotate all of
  `compiler/`); function params+returns mandatory-typed; full inference below
  signatures; **erased** types; full generics on classes AND enums; `float`
  finished; `Option<T>`/`Result<T>` as **generic enums**.

## Phases

- [x] **1 — type syntax + representation** (commit 2362162). `: Type`, `<T>`,
  `(A,B)->R`, `unit`; `TypeName`/`TypeFn` AST; `->` ARROW; parsed & erased.
- [x] **2 — float** (commit 614da32). FLOAT literals, fold `+ - * /`, `to_int`/
  `to_float`. (`/` is true float division; host Lua 5.3+.)
- [x] **3 — payload enum variants** (commit d24e6fb). `Some(int)`; payload →
  constructor fn → `{kind=..,_n=..}`; match `Some(v)` binds; arity checked.
- [x] **4 — core checker** (commit e132082). `frontend/typecheck/` pass; gradual
  `dynamic`; int≠float, condition-bool, annotated binding/return checks;
  local/field/param inference.
- [ ] **4b — finish the checker** (deferred from 4; can fold into 5):
  - Type call results from the callee's signature (currently `dynamic`). Needs a
    per-class/enum signature table (method name → param types + return type),
    built from all modules (like the enum registry in `Main`).
  - Type `.field` / member access from the receiver's class field types.
  - Call **argument count + types** checked against the signature.
  - Reassignment compatibility (only meaningful once vars are reliably typed).
  - `match` payload bindings get the variant's declared field types (registry
    already has `variant_arity`; extend to field types).
  - Decide `++`/comparison strictness on concrete types (currently lenient).
- [ ] **5 — generics**: type params on classes/enums in the `Type` model;
  instantiation `Name<Args>`; **type-arg inference by unification** at call/
  construction sites (needs 4b call typing); erasure (already erased at codegen —
  just don't emit type args). Type variables currently resolve to `dynamic` in
  `Typecheck.resolve`; make them real within a generic decl's scope.
- [ ] **6 — annotate `compiler/`**: add types to every function in `compiler/`
  (~35 files), file-by-file, `make selfhost` + `busted` after each. This is the
  long pole and the original comment-killing goal (deletes param/return-shape
  comments). The checker is lenient toward unannotated functions *until* this is
  done.
- [ ] **7 — enforce strict**: flip mandatory-signature checking on — a function
  with a missing/partial param or return annotation is an error. Only after 6.
- [ ] **8 — std rewrite**: `enum Option<T> { Some(T), None }`,
  `enum Result<T> { Ok(T), Err(str) }` with methods; delete the six
  `OptionInt/OptionString/OptionBool/ResultInt/ResultString/ResultBool`; repoint
  imports. Decide method surface (enum methods vs free functions) with the user.

## Key files
- Checker: `compiler/frontend/typecheck/Type.laz`, `Typecheck.laz`.
- Type syntax parsing: `compiler/frontend/parser/StmtParser.laz`
  (`parse_type`, `parse_type_params`, `parse_enum_variant`, param/return/field
  annotations), `Ast.laz` (`TypeName`/`TypeFn`/`enum_variant`).
- Registry plumbing: `Main.collect_enums` (+ `variant_owner`/`enums`/
  `variant_arity`) → `Schematic.analyze` → `StmtChecker`; the same pattern is how
  4b's signature table should reach `Typecheck`.
