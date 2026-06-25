# Tier 2 (sum types + match) — handoff for the next agent

Context: this is the "kill the comments" effort. Comments in `compiler/` are
mostly facts the untyped language can't state, so they can rot into lies. Tier 2
de-stringifies the AST (`Node{kind, attrs}` + `if k == "..."` ladders) by adding
real variant types and `match`. **Phase 1 (`match` statement) and Phase 2a
(`enum` + exhaustiveness, nullary variants) are DONE and verified.** What remains
is payload-carrying variants and the ladder migration (2b). This doc tells you
what is done, the rules you must follow, and what is left.

---

## Ground rules (read first — they are non-obvious)

1. **`src/` is FROZEN legacy.** Never edit it. `compiler/` (the `.laz`
   self-hosted compiler) is canonical. All language work goes in `compiler/`.

2. **New syntax is grown with the bootstrap ladder, not by editing `src/`:**
   - Implement the feature in `compiler/` using only **today's** syntax.
   - Build `compiler/` once with the seed: `lua src/cli.lua build compiler/Main.laz -o /tmp/lazc.lua`.
     The resulting `/tmp/lazc.lua` now *understands* the new feature.
   - Only then may `compiler/`'s own source *use* the feature, compiled by that
     new binary (not `src/`).
   - **Consequence to respect:** the instant any `compiler/*.laz` source *uses*
     new syntax, `src/` can no longer seed the build (it can't parse its own
     input). At that point you MUST commit a prebuilt self-host binary
     (`compiler.lua`) as the new seed and update the build process. **Do not
     cross this line without the user's explicit go-ahead.** As of this handoff,
     no `compiler/` source uses `match`, so `src/` still seeds.

3. **Always verify with the same four checks** (this is how Phase 1 was signed
   off):
   - Bootstrap-build: `lua src/cli.lua build compiler/Main.laz -o /tmp/lazc.lua`
   - Feature works: compile + run a test `.laz` with `/tmp/lazc.lua`. **NOTE:** the
     self-hosted `Main.laz` writes its output to a file named `Main.lua` in the
     CWD (not stdout). So run in a scratch dir with an ABSOLUTE entry path, then
     `lua ./Main.lua`, e.g. `(cd /tmp/b && lua /tmp/lazc.lua /abs/Entry.laz && lua Main.lua)`.
     Clean up stray `Main.lua` afterward so you don't pollute the repo root.
   - **Self-host fixpoint:** `/tmp/lazc.lua` builds `compiler/Main.laz` → stage2;
     stage2 builds it → stage3; `diff stage2 stage3` must be **identical**.
   - Suite: `busted` → must stay **394/0**.
   - Import paths resolve from the entry file's directory (`Linker.root =
     Path.dirname(entry)`); use absolute entry paths and put a `std/` dir
     (copy `compiler/std/*.laz`) beside the entry. NOTE: under the sandbox,
     `cp -r compiler/std /tmp/x/std` may create a broken symlink — copy the
     files explicitly: `mkdir -p /tmp/x/std && cp compiler/std/*.laz /tmp/x/std/`.

---

## What Phase 1 added (the `match` STATEMENT) — already done

Syntax (matches `doc/design/04-types-and-data.md`):

```
match <expr> {
    <pattern> => { <statements> }
    <pattern> => { <statements> }
    _         => { <statements> }      // optional catch-all
}
```

- `<pattern>` is any expression; an arm matches when `scrutinee == pattern`.
- `_` is the catch-all (lowered to `else`).
- Lowers to a Lua `if/elseif/else` ladder over a **once-evaluated** temp so the
  scrutinee's side effects run exactly once.

Design choices you must keep consistent:

- **`match` is a SOFT keyword** (Python-style). It stays an `IDENTIFIER` so
  `TokenCursor.match` and the ~16 `.cursor.match(...)` calls keep working. It is
  recognised only at statement head, by `StmtParser.starts_match()` (fires unless
  the next token is `(`, `=`, `.`, `[`, or a compound-assign — i.e. unless it's a
  call/assignment/member/index on something named `match`).
- **`=>` is `FAT_ARROW`**, added to `Keywords.ops2`.
- Temps come from `CgContext.fresh_temp()` → `__lz_m<n>`, unique per class block
  (covers nested matches).

Files touched (all in `compiler/`):

| Stage | File | Change |
|---|---|---|
| lexer | `frontend/lexer/Keywords.laz` | `"=>": "FAT_ARROW"` in `ops2` |
| parser | `frontend/parser/Ast.laz` | `match_stmt`, `match_arm`, `match_default` factories |
| parser | `frontend/parser/StmtParser.laz` | `starts_match`, `parse_match`, `parse_match_arm`; soft-keyword hook in `parse_statement` |
| schematic | `frontend/schematic/StmtChecker.laz` | `MatchStmt` dispatch + `check_match` |
| optimizer | `frontend/optimizer/StmtFolder.laz` | `MatchStmt` dispatch + `fold_match` |
| backend | `backend/StmtEmitter.laz` | `MatchStmt` dispatch + `emit_match` |
| backend | `backend/CgContext.laz` | `temp_seq` field + `fresh_temp()` |

AST shapes: `MatchStmt{scrutinee, arms, line, col}`;
`MatchArm{pattern, is_wildcard, body}` (wildcard arm omits `pattern`,
`is_wildcard = true`).

Verified: value/int/`_`/nested/arm-`return`/arm-reassign all correct; stable
fixpoint; 394/0 specs.

### Known limitation of Phase 1 (intended)
`match` is currently just sugar for an `if`-ladder: **no exhaustiveness**, and
patterns are value-equality only (no variant destructuring like `Some(v)`). That
is exactly what Phase 2 adds.

---

## Phase 2 — what to build next

### 2a. `enum` declarations + exhaustiveness — ✅ DONE (nullary variants)

Implemented and verified (stable fixpoint, 394/0, cross-file enum match works,
non-exhaustive match is rejected). What landed:

- **`enum` is a reserved keyword** (it was unused as an identifier, so no soft
  keyword needed). One file = one enum (file stem = enum name = table), like a
  class. Syntax `enum Name { A, B, C }`, variants separated by newline or optional
  comma. Lowers to `Name.A = 'A'`, … — **a nullary variant's value is its own
  name string**, so `match node.kind { LiteralExpr => ... }` already lines up with
  the parser writing `kind = "LiteralExpr"`.
- **Variant patterns in match:** a bare PascalCase `Variant =>` arm
  (`StmtParser.is_variant_name` = leading uppercase). Lowers to `temp == 'Variant'`.
- **Exhaustiveness:** an enum registry (`enums` = name→variants,
  `variant_owner` = variant→enum) is built in `Main.collect_enums` across ALL
  modules (each is analysed independently, so this is how an imported enum's
  variant set reaches the checker), threaded `Main → Schematic.analyze →
  StmtChecker`. `StmtChecker.check_match` resolves variant arms to one enum,
  rejects unknown/mixed/duplicate variants, and — absent a `_` — requires every
  variant covered.
- Files touched (added to the Phase-1 set): `Keywords` (`enum`), `Ast`
  (`enum_decl`, `match_variant`, `is_variant` flag on arms), `StmtParser`
  (`parse_enum`, variant-pattern arm, `is_variant_name`; imports `std.Str`),
  `StmtChecker` (registry fields + `check_variant_arm`/`check_exhaustive`),
  `Schematic.analyze` (+2 params), `Main` (`collect_enums`, registry),
  `StmtFolder` (`is_value_arm` guard), `StmtEmitter` (`emit_enum`, `match_test`).

**Still open inside 2a — payload-carrying variants** (`Some(v)`, `Circle(r)`):
destructuring/binding in patterns + non-string runtime rep. NOT needed for the
AST-`kind` migration (that tag is nullary), so it was deferred. If you add it:
extend `MatchArm` with bound names, declare them in the arm scope in
`check_match`, and have `emit_match` pull fields out of the tagged table.

#### Original 2a goal (for reference)
A declared variant type so `match` over it is **compile-time checked complete** —
turning every "everything else falls through" comment into a compiler guarantee.

Design target (from `doc/design/04-types-and-data.md`):
```
enum Shape { Circle(r), Square(s), Point }
match sh {
    Circle(r) => { ... }
    Square(s) => { ... }
    Point     => { ... }
}   // no `_` needed; compiler errors if a variant is unhandled
```

Decisions to make (and write down):
- **Surface:** `enum Name { Variant, Variant(field, ...), ... }`. Where can it be
  declared? Simplest: a top-level construct in its own file or alongside a class.
  Check how `Schematic`/`Codegen` model "one file = one class" first
  (`compiler/frontend/schematic/Schematic.laz`, `compiler/backend/Codegen.laz`) —
  enums likely need their own declaration path.
- **Runtime rep (erased):** a tagged table, mirroring the existing Option/list
  runtime — `{ kind = 'Circle', ... }`. See `compiler/backend/Runtime.laz` for
  the existing `{ kind = ... }` convention (tag strings are SINGLE-quoted so they
  sit inside Lazarus double-quoted literals — the lexer has no escapes).
- **Pattern binding:** `Circle(r) =>` must bind `r` in the arm scope. Extend
  `MatchArm` with bound names; `check_match` declares them in the arm's child
  scope; `emit_match` pulls them out of the tagged table.
- **Exhaustiveness:** the checker needs the enum's variant set. `StmtChecker`
  must know the scrutinee's enum type. Without full static types this is the hard
  part — options: (a) require an explicit enum annotation on the match, e.g.
  `match sh: Shape { ... }`; or (b) infer from the variant names used in the
  patterns. Pick the simplest that gives a real exhaustiveness error. Document
  the choice.
- Keep `_` working as an explicit catch-all that satisfies exhaustiveness.

Touch the same seven files as Phase 1, plus wherever top-level declarations are
gathered (`Schematic` instance/property collection; `Codegen` member
classification; `Bundler` if enums become their own emitted unit).

### 2b. Migrate the `if k == "..."` ladders to `match` (DEFER — cuts the cord)

This is the visible comment removal: rewrite the dispatch ladders in
`backend/ExprEmitter.laz`, `backend/StmtEmitter.laz`,
`frontend/schematic/StmtChecker.laz` / `ExprChecker.laz`,
`frontend/optimizer/StmtFolder.laz` / `ExprFolder.laz`, and ideally replace the
stringly-typed `Node{kind, attrs}` with enum variants.

**STOP before doing this without explicit user sign-off:** the moment these files
use `match`, `lua src/cli.lua build compiler/Main.laz` stops working (frozen
`src/` can't parse `match`). You must:
1. Commit a prebuilt self-host binary (e.g. `bin/compiler.lua`) built by the
   last `src/`-seeded, match-aware compiler.
2. Update `makefile` / `bin/lazarus` so the build seeds from that binary, not
   `src/`.
3. Re-establish the fixpoint from the new seed.

This is a deliberate, one-way self-hosting milestone — it's the user's call when
to take it.

---

## Related notes
- Tier 1 dispatch fix already landed in `compiler/backend/ExprEmitter.laz`
  (self-receiver guard); see memory `lazarus-reserved-method-names`. The
  reference `src/` still has that bug but is frozen, so ignore it.
- Don't collapse the six `std/Option*`/`Result*` classes — the compiler imports
  none of them and it contradicts `doc/design/04-types-and-data.md`.
- Full status in memory `lazarus-selfhost-compiler-status`.
