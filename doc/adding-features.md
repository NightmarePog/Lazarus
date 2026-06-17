# Lazarus – Adding a Language Feature

This is the standard recipe for implementing a new feature. Lazarus is a
five-stage pipeline (see [`pipeline.md`](pipeline.md)); a feature is added by
walking it **front to back**, touching only the stages the feature needs. Each
stage has a single, well-defined registration point so new code is *added*, not
threaded through existing functions.

```
Lexer ──▶ Parser ──▶ Schematic ──▶ Optimizer ──▶ Codegen
 token     AST node    rule          (optional)    Lua text
```

## The golden rules

1. **One concept, one file.** A new token, AST node, parse handler, check, or
   emitter lives in its own module. You register it in a `HANDLERS`/`TOKENS`
   table; you do not edit a giant `if/elseif` chain.
2. **Front to back.** Implement and test each stage before starting the next.
   A token the parser can't see is untestable; an AST node nothing emits is dead.
3. **Fail loud, fail early.** The earliest stage that *can* reject bad input
   *should*. Lexer rejects bad characters, parser rejects bad syntax, schematic
   rejects bad meaning. Never let an invalid program reach codegen.
4. **Positions everywhere.** Every token and every AST node carries `line`/`col`
   (or `column`). Thread them through so errors can point at the source.
5. **Test the stage you just wrote** before moving on (see [Testing](#testing)).

---

## Decide which stages your feature touches

| Feature kind | Lexer | Parser | Schematic | Optimizer | Codegen |
|---|:---:|:---:|:---:|:---:|:---:|
| New operator (e.g. `/`) | ● | ● | – | ○ | ● |
| New statement keyword (e.g. `while`) | ● | ● | ● | ○ | ● |
| New literal (e.g. floats) | ● | ● | – | ○ | ● |
| New semantic rule only | – | – | ● | – | – |
| New optimization only | – | – | – | ● | – |

● required ○ optional/recommended – not needed

---

## Stage 1 — Lexer  (`src/frontend/lexer/`)

Add the surface syntax so the scanner can produce a token for it.

1. **Add the `TokenType`** to the `---@alias TokenType` union in
   `keywords.lua`. This is the source of truth every other stage's annotations
   refer to.
2. **Map the source text → type** in the `TOKENS_DATA` table in `keywords.lua`
   (keywords like `["while"] = "WHILE"`, operators like `["/"] = "DIVIDE"`).
3. If the token may appear **inside an expression** (an operator or value), add
   it to `VALID_TYPES` in `keywords.lua`. Keyword-only tokens are deliberately
   left out so they can never fall through to expression-statement parsing.
4. For anything the byte-scanner doesn't already handle (multi-char operators,
   new literal shapes), extend the scanner in `lexer/init.lua`. Single
   characters and `[a-zA-Z_]` words are already covered.
5. Emit a lexer error (`UNEXPECTED_CHAR`, `INVALID_NUMBER`, …) for malformed
   input rather than producing a garbage token.

**Test:** add cases to `spec/lexer_spec.lua` asserting the token stream.

---

## Stage 2 — Parser  (`src/frontend/parser/`)

Turn tokens into a typed AST node.

### a. Define the AST node — `parser/nodes/<name>.lua`

Copy the shape of an existing node (`nodes/return.lua` is the minimal example):

- A `---@class XStmt: Stmt` (or `: Expr`) block listing every field, including
  `line`/`col`.
- `X.new(...)` returns a `setmetatable({ type = "XStmt", … }, X)`. The `type`
  string is the dispatch key for every later stage — keep it unique.
- A `__tostring` for readable test failures and `ast` dumps.

### b. Write the handler

**Statement keyword** → `parser/statements/<keyword>.lua`:

```lua
local StatementParser = require("frontend.parser.statements.statement_parser")
return StatementParser.new("WHILE", function(parser)
    -- the keyword token is already consumed; parser:_previous() is it
end)
```

Then register it in the `HANDLERS` list in `parser/statements/init.lua`. The
dispatcher builds the keyword→handler registry automatically — no other edit.

**Operator** → add it to the precedence table in
`parser/expressions/operators.lua` (and a node + emit rule). The
precedence-climbing parser in `expressions/binary.lua` picks it up.

**Expression form** (new primary, postfix, etc.) → extend the matching module
under `parser/expressions/` (`primary.lua`, `call.lua`).

Use `parser:_match`, `_check`, `_consume`, `_advance` for token handling, and
throw `SYNTAX_ERROR` / `UNEXPECTED_TOKEN` / `UNEXPECTED_EOF` via `Error.throw`
with the offending token's position.

**Test:** `spec/parser_spec.lua` — assert the AST structure (`tostring` or field
checks).

---

## Stage 3 — Schematic  (`src/frontend/schematic/`)

Validate meaning. Only needed if the node has rules (scope, duplicates,
position, type). Pure syntactic sugar can skip this stage.

1. Create a check module — `schematic/statements/<name>.lua` or
   `schematic/expressions/<name>.lua` — implementing the
   `StatementCheck` / `ExpressionCheck` interface (`type` = your node's `type`
   string, plus a `check` function).
2. Register it in the relevant `HANDLERS` list
   (`schematic/statements/init.lua` or `schematic/expressions/init.lua`).
3. Use the `SemContext` helpers from `schematic/init.lua` for scope, name
   binding, duplicate detection, and recursing into child blocks. Don't
   reimplement scoping.
4. Reject violations with `SEMANTIC_ERROR` at the node's position. If the rule
   records a verdict codegen needs (like `reassign`), set it on the node here.

**Test:** `spec/schematic_spec.lua` / `spec/error_spec.lua` — assert both that
valid programs pass and that invalid ones throw the right error.

---

## Stage 4 — Optimizer  (`src/frontend/optimizer/`)  *(optional)*

Only if your feature enables a compile-time rewrite (folding, propagation,
algebraic simplification). Optimizations must be **meaning-preserving** and are
applied bottom-up in `optimizer/expr.lua` (`fold_expr`); statement-level walking
lives in `optimizer/init.lua`. Skip mutable bindings and reassignments. If you
don't add anything, existing nodes pass through untouched — that's fine.

**Test:** `spec/optimizer_spec.lua`.

---

## Stage 5 — Codegen  (`src/backend/lua50/`)

Serialise the node to Lua text. No transformation happens here — the AST is
already final.

- Statement node → add a branch in `emit_stmt` (`backend/lua50/stmt.lua`).
- Expression node → add a branch in `emit_expr` (`backend/lua50/expr.lua`).

Match on `node.type`, `---@cast` it, and return the Lua string. Reuse `indent`
for nested bodies and parenthesise sub-expressions where Lua precedence
requires it (see how `BinaryExpr` is handled). The final `error(... unknown
node type ...)` guard means a forgotten branch fails loudly in tests.

**Test:** `spec/codegen_spec.lua` — assert the exact emitted Lua. End-to-end
behaviour goes in `spec/integration_spec.lua`.

---

## Testing

Specs live in `spec/` and run with `make test` (busted). One spec file per
stage, mirroring the pipeline. The convention (see `spec/codegen_spec.lua`) is a
small `build`/`compile` helper that runs the pipeline up to the stage under
test, then `assert.equal` on the result.

A complete feature should land with, at minimum:

- the token in `lexer_spec`,
- the AST shape in `parser_spec`,
- any rule (pass **and** fail) in `schematic_spec` / `error_spec`,
- the emitted Lua in `codegen_spec`,
- one real program in `integration_spec`.

Run `make test`, `make lint` (selene), and `make format` (stylua) before
considering the feature done.

---

## Worked example — adding the `/` (divide) operator

1. **Lexer:** add `"DIVIDE"` to the `TokenType` alias, `["/"] = "DIVIDE"` to
   `TOKENS_DATA`, and `DIVIDE = true` to `VALID_TYPES` (all in `keywords.lua`).
   → `lexer_spec`.
2. **Parser:** add `DIVIDE` to `expressions/operators.lua` at multiplicative
   precedence. Reuses the existing `BinaryExpr` node. → `parser_spec`.
3. **Schematic:** nothing — division has no new semantic rule.
4. **Optimizer:** add `x / 1 → x` to the simplification table and constant
   folding for two numeric literals in `optimizer/expr.lua`. → `optimizer_spec`.
5. **Codegen:** the `BinaryExpr` branch in `expr.lua` already emits
   `left op right`; just make sure `op` maps to `/`. → `codegen_spec`.

Each stage is one small, registered addition — that is the standard to aim for.
