# Lazarus – Adding a Language Feature

This is the standard recipe for implementing a new feature. Lazarus is a
six-stage pipeline (see [`pipeline.md`](pipeline.md)); a feature is added by
walking it **front to back**, touching only the stages the feature needs. Each
stage has a single, well-defined registration point so new code is *added*, not
threaded through existing `if/elseif` chains.

```
Lexer → Parser → Schematic → Typecheck → Optimizer → Codegen
token    node     rule         type rule   (optional)  Lua text
```

## The golden rules

1. **One concept, one file.** A new token, AST node, parse handler, check, or
   emitter lives in its own module. Register it in a `HANDLERS`/`TOKENS` table;
   never add to a giant `if/elseif` chain.
2. **Front to back.** Implement and test each stage before the next. A token
   the parser can't see is untestable; an AST node nothing emits is dead.
3. **Fail loud, fail early.** The earliest stage that *can* reject bad input
   *should*. Lexer rejects bad characters, parser rejects bad syntax, Schematic
   rejects bad semantics, Typecheck rejects type mismatches.
4. **Positions everywhere.** Every token and AST node carries `line`/`col`.
   Thread them through so errors can point at the source.
5. **Verify with `make selfhost`** after each stage. A broken stage surfaces
   immediately; a fixpoint failure means the new code changes its own
   compilation.

---

## Which stages does your feature touch?

| Feature kind | Lexer | Parser | Schematic | Typecheck | Optimizer | Codegen |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| New operator | ● | ● | – | – | ○ | ● |
| New statement keyword | ● | ● | ● | ○ | ○ | ● |
| New literal type | ● | ● | – | ○ | ○ | ● |
| New semantic rule only | – | – | ● | – | – | – |
| New type rule | – | – | – | ● | – | – |
| New optimization pass | – | – | – | – | ● | – |

● required ○ optional – not needed

---

## Stage 1 — Lexer (`compiler/frontend/lexer/`)

1. **Add the keyword or token kind** to the map in `Keywords.object.laz`
   (e.g. `"while": "WHILE"`). This is the source of truth for every stage.
2. For operators not already handled by the byte scanner, extend `Lexer.class.laz`.
   Single characters and `[a-zA-Z_]` words are already covered.
3. If the token can appear inside an expression, make sure the parser's
   precedence table (in `ExprParser`) knows about it.
4. Emit an error with a clear message for malformed input rather than
   producing a garbage token.

---

## Stage 2 — Parser (`compiler/frontend/parser/`)

### a. Define the AST node in `Ast.object.laz`

Add one named constructor that builds a `Node` with the right `kind` tag and
attribute map. Every node must carry `line`/`col`. Use an existing factory
method as a template (`Ast.while_stmt` is the minimal example).

### b. Write the parse handler in `StmtParser.class.laz` or `ExprParser.class.laz`

Statement keywords — add a branch to the `match tok.kind` block in
`parse_statement()` that advances past the keyword and calls a `private
parse_<name>()` method.

Operators — add the token to the `precedences` map in `ExprParser.class.laz`.
The precedence-climbing loop picks it up automatically; you only need an
`Ast` node and a codegen rule if the operator produces a new node kind.

Type syntax — extend `TypeParser.class.laz`.

Use `TokenCursor` helpers (`cursor.consume`, `cursor.match`, `cursor.check`,
`cursor.fail`) for token handling. Never advance the cursor directly except
through these methods.

### c. Register

If the new node needs special Schematic or Codegen handling, both are
dispatched through `match node.kind` tables — add the case there.

---

## Stage 3 — Schematic (`compiler/frontend/schematic/`)

Only needed if the node has semantic rules (scope, duplicates, position checks,
new declaration forms).

- **Statement node** → add a case to `StmtChecker.check_statement`.
- **Expression node** → add a case to `ExprChecker.check_expr`.
- Use `Scope` helpers for name binding and `Frame` for control-flow context.
  Don't reimplement scoping.
- If the rule records a verdict that codegen needs (e.g. `reassign`), set it on
  the node here with `node.set("reassign", true)`.
- Reject violations with `.fail(node, message, span)`.

---

## Stage 4 — Typecheck (`compiler/frontend/typecheck/`)

Only needed for new type rules (new generic forms, new built-in types, call
signature changes). Most feature additions don't require Typecheck changes.

Typecheck receives the program-wide class signatures and enum registries built
by `Collector` and checks each expression bottom-up, inferring and verifying
`Type` values.

---

## Stage 5 — Optimizer (`compiler/frontend/optimizer/`)

Only needed for compile-time rewrites. Add a case to `ExprFolder` or
`StmtFolder`. Optimizations must be meaning-preserving. Skip mutable bindings
and reassignment targets.

Inlining (O2) and constant folding are applied bottom-up; propagation
(constants table) is top-down. Don't add to the optimizer unless the rewrite
is semantically safe in all cases.

---

## Stage 6 — Codegen (`compiler/backend/`)

Serialize the node to Lua text. No transformation — the AST is final.

- Statement node → add a case to `StmtEmitter.emit_member` / `emit_stmt`.
- Expression node → add a case to `ExprEmitter.emit_expr`.

Match on `node.kind`, read attributes with `node.attr(...)` / `node.child(...)`,
and return the Lua string. Use `Text.indent` for nested bodies. The default
`else` branch errors loudly, so a forgotten case surfaces in selfhost.

---

## Verification

After each stage addition, run:

```sh
make selfhost     # recompile the compiler with itself; verifies the fixpoint
```

A broken parse/semantic/codegen rule will surface immediately because the
compiler compiles itself. If selfhost produces a fixpoint failure (stage2 ≠
stage3), the new code changed how its own output is lowered — usually a codegen
rule that affects a construct the compiler uses.

---

## Worked example — adding a new `unless` keyword

1. **Lexer:** add `"unless": "UNLESS"` to `Keywords.object.laz`.
2. **Parser:** in `StmtParser.parse_statement`, add:
   ```
   "UNLESS" => { .cursor.advance() return .parse_unless(tok) }
   ```
   Then `parse_unless` consumes the condition and body, returns
   `Ast.if_stmt([{condition: Ast.unary("NOT", cond, …), body}], [], …)` — an
   `IfStmt` with a negated condition (reuse the existing node; no new AST node
   needed).
3. **Schematic:** no new rule — `IfStmt` is already checked.
4. **Optimizer:** no change — `IfStmt` folding already handles negation.
5. **Codegen:** no change — `IfStmt` emits correctly.
6. **Selfhost:** `make selfhost` — fixpoint must hold.

Each stage is one small, registered addition.
