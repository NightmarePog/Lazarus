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
| `CONSTANT` | `constant` |
| `IDENTIFIER` | any `[a-zA-Z_][a-zA-Z0-9_]*` not matched as a keyword |
| `NUMBER` | decimal integer literal |
| `STRING` | double-quoted string literal |
| `ASSIGN` | `=` |
| `PLUS` | `+` |
| `MINUS` | `-` |
| `MULTIPLY` | `*` |
| `LEFT_BRACKET` | `(` |
| `RIGHT_BRACKET` | `)` |

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
| `VariableDecl` | `name: string`, `value: Expr \| nil` | `private x = expr` |
| `ConstantDecl` | `name: string`, `value: Expr` | `constant x = expr` (initialiser required) |
| `ExpressionStmt` | `expression: Expr` | bare expression as statement |

**Expression nodes**

| Node | Fields | Example |
|---|---|---|
| `LiteralExpr` | `kind: "number"\|"string"`, `value: any` | `42`, `"hello"` |
| `IdentifierExpr` | `name: string` | `foo` |
| `BinaryExpr` | `op: TokenType`, `left: Expr`, `right: Expr` | `a + b` |

### Operator precedence (low → high)

| Level | Operators |
|---|---|
| Additive | `+` `-` |
| Multiplicative | `*` |
| Primary | literals, identifiers, `(` grouped `)` |

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `Parser` class — cursor, `_advance`, `_match`, `_consume`, `parse()` |
| `types.lua` | `Expr` and `Stmt` base class annotations |
| `ast.lua` | `AST` (Program) node |
| `expressions.lua` | `_expression`, `_additive`, `_multiplicative`, `_primary` — mixed into `Parser` |
| `statements/init.lua` | `_statement` dispatcher — keyword → handler registry |
| `statements/statement_parser.lua` | `StatementParser` interface (keyword + parse fn) |
| `statements/let.lua` | Handler for `private` |
| `statements/constant.lua` | Handler for `constant` |
| `nodes/*.lua` | One file per AST node type |

### Errors

| Type | Trigger |
|---|---|
| `SYNTAX_ERROR` | Missing expected token, uninitialised `constant`, etc. |
| `UNEXPECTED_TOKEN` | Keyword-only token appearing in expression position |
| `UNEXPECTED_EOF` | Token expected but stream is exhausted |

---

## Stage 3 — Schematic

**Input:** `AST`  
**Output:** `AST` (same object, validated)  
**Files:** `src/frontend/schematic/`

Single-pass semantic checker. Walks the AST in source order maintaining a flat symbol table. Throws on the first violation.

### Rules

| Rule | Error |
|---|---|
| `VariableDecl` / `ConstantDecl` with a name already in scope | `SEMANTIC_ERROR` — duplicate declaration |
| `IdentifierExpr` whose name is not in the symbol table | `SEMANTIC_ERROR` — undeclared identifier |

### Symbol table entry

```lua
{ kind = "variable" | "constant" }
```

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `analyze(ast, source)` — statement walk, symbol table |
| `expr.lua` | `check_expr(node, symbols, source)` — recursive identifier validation |

---

## Stage 4 — Optimizer

**Input:** `AST`  
**Output:** `AST` (mutated in place)  
**Files:** `src/frontend/optimizer/`

Rewrites expression nodes bottom-up. Two passes happen in a single tree walk:

**1. Constant propagation** — when a `ConstantDecl`'s value folds to a `LiteralExpr`, its name is added to a `constants` table. Any later `IdentifierExpr` referencing that name is replaced with the literal.

**2. Constant folding** — `BinaryExpr` nodes where both operands are numeric `LiteralExpr` are evaluated at compile time and replaced with a single `LiteralExpr`.

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
constant foo = 3 + 2          →  constant foo = 5
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
| `VariableDecl { name, value }` | `local name = <expr>` |
| `VariableDecl { name, value=nil }` | `local name` |
| `ConstantDecl { name, value }` | `local name = <expr>` (Lua has no const — immutability is compile-time only) |
| `ExpressionStmt { expression }` | `<expr>` |
| `LiteralExpr { kind="number", value }` | `42` |
| `LiteralExpr { kind="string", value }` | `"hello"` (via `string.format("%q", …)`) |
| `IdentifierExpr { name }` | `name` |
| `BinaryExpr { op, left, right }` | `left op right` (inner `BinaryExpr` operands are parenthesised) |

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
