# Lazarus – Compiler Pipeline

## Overview

```
source: string
  │
  ▼
Lexer                   frontend/lexer/
  │  Token[]
  ▼
Parser                  frontend/parser/
  │  AST (Program)
  ▼
Schematic               frontend/schematic/
  │  AST (validated, same structure)
  ▼
Optimizer               frontend/optimizer/
  │  AST (folded/simplified, same structure)
  ▼
Codegen                 backend/lua50/
  │  string
  ▼
Lua 5.0 source
```

Entry point (dev): `src/repl.lua`

---

## Stage 1 — Lexer

**Input:** `string`  
**Output:** `Token[]`  
**Files:** `src/frontend/lexer/`

Single-pass scanner. Walks the source byte by byte and emits a flat list of tokens. Whitespace is discarded. Every token records its `line` and `column` so downstream errors can point at the source.

### Token fields

| Field | Type | Description |
|---|---|---|
| `type` | `TokenType` | Symbolic kind (`"NUMBER"`, `"IDENTIFIER"`, `"PLUS"`, …) |
| `value` | `string` | Raw source text |
| `literal` | `string \| number \| nil` | Converted value — number for `NUMBER`, string content for `STRING`, nil for everything else |
| `line` | `integer` | 1-based source line |
| `column` | `integer` | 1-based source column |

### Token types

| Token | Source text |
|---|---|
| `PRIVATE` | `private` |
| `PUBLIC` | `public` |
| `MUTABLE` | `mut` |
| `FUNCTION` | `fn` |
| `RETURN` | `return` |
| `IDENTIFIER` | any `[a-zA-Z_][a-zA-Z0-9_]*` not matched as a keyword |
| `NUMBER` | decimal integer literal |
| `STRING` | double-quoted string literal |
| `ASSIGN` | `=` |
| `PLUS` | `+` |
| `MINUS` | `-` |
| `MULTIPLY` | `*` |
| `LEFT_BRACKET` | `(` |
| `RIGHT_BRACKET` | `)` |
| `BODY_START` | `{` |
| `BODY_END` | `}` |
| `COMMA` | `,` |

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `Lexer` class — `Lexer.new(source):scan()` |
| `token.lua` | `Token` class definition |
| `keywords.lua` | `TOKENS` map (source text → `TokenType`) and `VALID_TYPES` guard set |
| `token_builder.lua` | Test helpers — builds `Token` values without running the lexer |

### Errors

| Type | Trigger |
|---|---|
| `UNEXPECTED_CHAR` | Character not recognised by any scanner rule |
| `UNTERMINATED_STRING` | EOF or newline before closing `"` |
| `INVALID_NUMBER` | Letter immediately following digits (e.g. `123abc`) |

---

## Stage 2 — Parser

**Input:** `Token[]`  
**Output:** `AST` (`Program` node)  
**Files:** `src/frontend/parser/`

Recursive-descent parser. Consumes the token list and builds a typed AST. Expressions and statement handlers live in separate modules and are mixed into the `Parser` class at load time.

### AST structure

```
Program
  └─ body: Stmt[]
```

**Statement nodes**

| Node | Fields | Source |
|---|---|---|
| `VariableDecl` | `name: string`, `value: Expr \| nil`, `visibility: "private"\|"public"\|nil`, `mutable: bool` | `private x = e`, `public mut x = e`, `mut x = e`, `x = e` |
| `FunctionDecl` | `name: string`, `params: string[]`, `body: Stmt[]` | `fn f(a, b) { ... }` |
| `ReturnStmt` | `value: Expr \| nil` | `return expr` / bare `return` |
| `ExpressionStmt` | `expression: Expr` | bare expression as statement |

**Bindings.** A single `VariableDecl` covers every binding form. Bindings are
**immutable by default**; `mut` opts into reassignability. Visibility
(`private`/`public`) is required at top level and omitted for function locals. A
bare `x = e` is a declaration the first time the name is seen and a reassignment
thereafter — the parser emits the same node and Schematic resolves which it is.
An immutable binding must be initialised. There is no `const` keyword: the
optimizer folds any binding with a foldable initialiser automatically.

**Expression nodes**

| Node | Fields | Example |
|---|---|---|
| `LiteralExpr` | `kind: "number"\|"string"`, `value: any` | `42`, `"hello"` |
| `IdentifierExpr` | `name: string` | `foo` |
| `BinaryExpr` | `op: TokenType`, `left: Expr`, `right: Expr` | `a + b` |
| `CallExpr` | `callee: Expr`, `args: Expr[]` | `f(a, b)` |

### Operator precedence (low → high)

| Level | Operators |
|---|---|
| Additive | `+` `-` |
| Multiplicative | `*` |
| Call | postfix `f(...)` |
| Primary | literals, identifiers, `(` grouped `)` |

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `Parser` class — cursor, `_advance`, `_match`, `_consume`, `parse()` |
| `types.lua` | `Expr` and `Stmt` base class annotations |
| `ast.lua` | `AST` (Program) node |
| `expressions/init.lua` | Collects expression rules and mixes them into `Parser` |
| `expressions/operators.lua` | Infix operator → precedence table (add an operator here) |
| `expressions/binary.lua` | `_expression` / `_binary` — precedence-climbing infix parser |
| `expressions/call.lua` | `_call` — postfix call parsing |
| `expressions/primary.lua` | `_primary` — literals, identifiers, grouping |
| `statements/init.lua` | `_statement` dispatcher — keyword → handler registry, plus bare `IDENT =` lookahead |
| `statements/statement_parser.lua` | `StatementParser` interface (keyword + parse fn) |
| `statements/binding.lua` | `read_binding` — shared binding parser (name, optional `= expr`) |
| `statements/{private,public,mut,function,return}.lua` | One handler per statement keyword |
| `nodes/*.lua` | One file per AST node type |

### Errors

| Type | Trigger |
|---|---|
| `SYNTAX_ERROR` | Missing expected token, uninitialised immutable binding, etc. |
| `UNEXPECTED_TOKEN` | Keyword-only token appearing in expression position |
| `UNEXPECTED_EOF` | Token expected but stream is exhausted |

---

## Stage 3 — Schematic

**Input:** `AST`  
**Output:** `AST` (same object, validated)  
**Files:** `src/frontend/schematic/`

Single-pass semantic checker. Walks the AST in source order maintaining a symbol table. A function body is checked in a child scope that inherits the enclosing declarations (lexical scoping) and adds the parameters; declarations inside it stay local. Throws on the first violation.

### Rules

| Rule | Error |
|---|---|
| `VariableDecl` / `FunctionDecl` with a name already in the same scope | `SEMANTIC_ERROR` — duplicate declaration |
| Top-level `VariableDecl` declaration with no visibility modifier | `SEMANTIC_ERROR` — must declare visibility |
| Bare `x = e` rebinding a name whose existing binding is not `mut` | `SEMANTIC_ERROR` — cannot assign to immutable binding |
| `IdentifierExpr` whose name is not visible in scope | `SEMANTIC_ERROR` — undeclared identifier |
| `FunctionDecl` with two parameters sharing a name | `SEMANTIC_ERROR` — duplicate parameter |
| `ReturnStmt` outside any function | `SEMANTIC_ERROR` — `'return'` outside of a function |
| `ReturnStmt` that is not the last statement in its block | `SEMANTIC_ERROR` — `'return'` must be last (mirrors Lua) |
| `ExpressionStmt` whose expression is not a call | `SEMANTIC_ERROR` — bare expressions are not valid statements |

The function name is bound in the enclosing scope *before* its body is walked, so a function may refer to itself (recursion).

A `VariableDecl` is a **declaration** when it carries `private`/`public`/`mut` or
when its bare name is not yet visible; otherwise it is a **reassignment**.
Schematic records the verdict on the node (`reassign`) for codegen. Function
parameters bind as immutable, so reassigning a parameter is rejected.

### Symbol table entry

```lua
{ kind = "variable" | "constant" | "function", mutable = boolean }
```

### Internal structure

Each rule lives in its own module, dispatched by AST node type. The driver
(`init.lua`) owns the shared `SemContext` (duplicate detection, name binding,
scope creation, block recursion); the rules stay small.

| File | Role |
|---|---|
| `init.lua` | `analyze(ast, source)` — driver + `SemContext` helpers |
| `statements/init.lua` | Statement-check dispatcher — node type → rule registry |
| `statements/statement_check.lua` | `StatementCheck` interface (`type` + `check`) |
| `statements/{variable,function,return,expression}.lua` | One check per statement node |
| `expressions/init.lua` | `check_expr` dispatcher over expression rules |
| `expressions/expression_check.lua` | `ExpressionCheck` interface (`type` + `check`) |
| `expressions/{identifier,binary,call}.lua` | One check per expression node |

---

## Stage 4 — Optimizer

**Input:** `AST`  
**Output:** `AST` (mutated in place)  
**Files:** `src/frontend/optimizer/`

Rewrites expression nodes bottom-up. Two passes happen in a single tree walk:

**1. Constant propagation** — when an *immutable* `VariableDecl`'s value folds to a `LiteralExpr`, its name is added to a `constants` table. Any later `IdentifierExpr` referencing that name is replaced with the literal. Mutable bindings and reassignments are skipped — their value can change.

**2. Constant folding** — `BinaryExpr` nodes where both operands are numeric `LiteralExpr` are evaluated at compile time and replaced with a single `LiteralExpr`.

Function bodies are folded recursively. Constants visible from the enclosing scope still propagate into a body, but a parameter of the same name shadows them and is left untouched.

**3. Algebraic simplification** — applied after folding on the same node:

| Pattern | Result |
|---|---|
| `x + 0`, `0 + x` | `x` |
| `x - 0` | `x` |
| `x * 0`, `0 * x` | `LiteralExpr(0)` |
| `x * 1`, `1 * x` | `x` |
| `x / 1` | `x` |

### Example

```
private foo = 3 + 2           →  private foo = 5
private x   = 5 + 5 - 2 * (2 + foo)
                              →  private x = -4
```

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `optimize(ast)` — statement walk, constants table, calls `fold_stmt` |
| `expr.lua` | `fold_expr(node, constants)` — recursive folding, propagation, simplification |

---

## Stage 5 — Codegen

**Input:** `AST`  
**Output:** `string` (Lua 5.0 source)  
**Files:** `src/backend/lua50/`

Walks the optimised AST and emits Lua source line by line. No transformations — purely a serialisation step.

### Emission rules

| AST node | Lua output |
|---|---|
| `VariableDecl` (private/local declaration) | `local name = <expr>` (or `local name` when valueless) |
| `VariableDecl { visibility="public" }` | `name = <expr>` (a Lua global) |
| `VariableDecl { reassign=true }` | `name = <expr>` (no `local` — rebinds an existing name) |
| `FunctionDecl { name, params, body }` | `local function name(params)` + indented body + `end` |
| `ReturnStmt { value }` | `return <expr>`, or `return` when `value=nil` |
| `ExpressionStmt { expression }` | `<expr>` |
| `LiteralExpr { kind="number", value }` | `42` |
| `LiteralExpr { kind="string", value }` | `"hello"` (via `string.format("%q", …)`) |
| `IdentifierExpr { name }` | `name` |
| `BinaryExpr { op, left, right }` | `left op right` (inner `BinaryExpr` operands are parenthesised) |
| `CallExpr { callee, args }` | `callee(arg, arg)` |

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `Codegen` class — `Codegen.new(ast):generate()` |
| `stmt.lua` | `emit_stmt(node)` — statement → Lua string |
| `expr.lua` | `emit_expr(node)` — expression → Lua string |

`src/backend/init.lua` delegates to `backend.lua50` and is the public entry point (`require "backend"`).

---

## Error system

All stages share `src/error.lua`. Errors are thrown with `Error.throw(type, message, line, col, source, span)` and rendered as a coloured box with a source snippet and caret.

```
╭─ Error ──────────────────────────────
│ Type: SEMANTIC_ERROR
│ Location: unknown:2:14
│
│   2 │   private x = undefined_var
│                     ^^^^^^^^^^^^^
╰──────────────────────────────────────
```

### Error types

| Constant | Stage |
|---|---|
| `UNEXPECTED_CHAR` | Lexer |
| `UNTERMINATED_STRING` | Lexer |
| `INVALID_NUMBER` | Lexer |
| `UNEXPECTED_EOF` | Parser |
| `UNEXPECTED_TOKEN` | Parser |
| `SYNTAX_ERROR` | Parser |
| `SEMANTIC_ERROR` | Schematic |
