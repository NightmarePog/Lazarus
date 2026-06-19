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

To add a new language feature, follow [`adding-features.md`](adding-features.md)
— the standard stage-by-stage recipe built on this pipeline.

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
| `DIVIDE` | `/` |
| `MODULO` | `%` |
| `POWER` | `^` |
| `CONCAT` | `++` (string concatenation; lowers to Lua `..`) |
| `LEFT_BRACKET` | `(` |
| `RIGHT_BRACKET` | `)` |
| `BODY_START` | `{` |
| `BODY_END` | `}` |
| `COMMA` | `,` |
| `COLON` | `:` (introduces a type annotation) |
| `SEMICOLON` | `;` (only used inside a `for` header) |
| `IF` `ELSE` `WHILE` `LOOP` `FOR` `BREAK` | the control-flow keywords |
| `TRUE` `FALSE` | boolean literals |
| `AND` `OR` `NOT` | logical operators |
| `EQ` `NEQ` `LESS` `LESS_EQUAL` `GREATER` `GREATER_EQUAL` | `==` `!=` `<` `<=` `>` `>=` |
| `PLUS_ASSIGN` `MINUS_ASSIGN` `STAR_ASSIGN` `SLASH_ASSIGN` | `+=` `-=` `*=` `/=` |

Multi-character operators (`==`, `<=`, `+=`, `++`, …) are matched by **maximal munch**: the scanner prefers the two-character token over the single-character one.

Comments are skipped by the scanner and produce no tokens: `// …` runs to end of line, `/* … */` spans lines (an unterminated block comment is an `UNTERMINATED_COMMENT` error). The leading `/` is disambiguated before symbol scanning, so `/`, `/=`, `//` and `/*` never collide.

A number literal with a fractional part (`3.14`) is a float; the lexer leaves a `.` that is not followed by a digit as a separate token.

**Type annotations.** Bindings (`name: Type`), function parameters (`p: Type`) and return types (`fn f(): Type`) carry an optional `TypeRef` (`{ name }`). They are parsed onto `VariableDecl.type_ann` and `FunctionDecl.param_types`/`return_type`. The type *checker* lives in Schematic; annotations are **erased** before codegen, so the emitted Lua is identical with or without them.

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
| `IfStmt` | `clauses: {condition, body}[]`, `else_body: Stmt[] \| nil` | `if c { } else if d { } else { }` |
| `WhileStmt` | `condition: Expr`, `body: Stmt[]` | `while c { ... }` |
| `LoopStmt` | `body: Stmt[]` | `loop { ... }` |
| `ForStmt` | `init: Stmt?`, `condition: Expr?`, `step: Stmt?`, `body: Stmt[]` | `for i = 0; i < n; i += 1 { }` |
| `BreakStmt` | — | `break` |

**Control flow.** Conditions take no parentheses; braces are required. The
C-style `for` is written **without parentheses** (`for i = 0; i < n; i += 1 { }`)
— a deliberate deviation from `doc/design/05-control-flow.md`. Its `init`/`step`
are assignment statements and any clause may be empty. **Compound assignment**
(`i += 1`) is desugared by the parser into a plain reassignment (`i = i + 1`), so
no node type represents it. There is no type system yet, so a condition is any
expression (Lua truthiness applies at runtime) rather than a checked `bool`.

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
| `LiteralExpr` | `kind: "number"\|"string"\|"boolean"`, `value: any` | `42`, `"hello"`, `true` |
| `IdentifierExpr` | `name: string` | `foo` |
| `BinaryExpr` | `op: TokenType`, `left: Expr`, `right: Expr` | `a + b`, `a == b`, `a and b` |
| `UnaryExpr` | `op: TokenType`, `operand: Expr` | `not done` |
| `CallExpr` | `callee: Expr`, `args: Expr[]` | `f(a, b)` |

### Operator precedence (low → high)

| Level | Operators |
|---|---|
| Logical or | `or` |
| Logical and | `and` |
| Comparison / equality | `==` `!=` `<` `<=` `>` `>=` |
| Additive / concat | `+` `-` `++` |
| Multiplicative | `*` `/` `%` |
| Exponent | `^` |
| Unary | prefix `not` |
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
| `expressions/unary.lua` | `_unary` — prefix `not` |
| `expressions/call.lua` | `_call` — postfix call parsing |
| `expressions/primary.lua` | `_primary` — literals (incl. `true`/`false`), identifiers, grouping |
| `statements/init.lua` | `_statement` dispatcher + `_block` helper (`{ stmt* }`); bare `IDENT =`/`+=` lookahead |
| `statements/statement_parser.lua` | `StatementParser` interface (keyword + parse fn) |
| `statements/binding.lua` | `read_binding` / `read_assignment` — shared binding & assignment parsers (incl. compound `+=` desugaring) |
| `statements/{private,public,mut,function,return}.lua` | One handler per statement keyword |
| `statements/{if,while,loop,for,break}.lua` | One handler per control-flow keyword |
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
| `BreakStmt` outside any loop | `SEMANTIC_ERROR` — `'break'` outside of a loop |
| `BreakStmt` that is not the last statement in its block | `SEMANTIC_ERROR` — `'break'` must be last (Lua 5.0 requires it) |
| Binding/return value not assignable to its declared type | `TYPE_MISMATCH` |
| Mixing `int` and `float`, or non-numeric arithmetic operand | `TYPE_MISMATCH` |
| `++` on non-`str`, `and`/`or`/`not` on non-`bool`, equality across types | `TYPE_MISMATCH` |
| `if`/`while`/`for` condition that is not `bool` | `TYPE_MISMATCH` |
| Value name (variable/function/parameter/loop var) not `snake_case` | `SEMANTIC_ERROR` |
| Type name not `PascalCase` (built-in scalars exempt) | `SEMANTIC_ERROR` |

### Type checking

Schematic also runs a **gradual** static type check (`schematic/types.lua`).
Each scope entry carries a `vtype` (`int`/`float`/`str`/`bool`/`any`); an
annotation sets it, otherwise it is inferred from the initialiser. Anything
unknown is `any` and flows without error, so un-annotated code still checks.
`int` and `float` are **distinct** and never convert implicitly. Types are
**erased** after this pass — Optimizer and Codegen see a plain AST. Call results
are `any` for now (call-site argument checking arrives with class/function
signatures later). User type names (non-scalars) are treated as `any` until
classes exist.

Control-flow bodies (`if`/`while`/`loop`/`for`) are checked in **child scopes**
that inherit the enclosing declarations; bindings made inside a body stay local.
The `for` loop variable is a fresh, implicitly-**mutable** binding scoped to the
loop, exempt from the top-level visibility rule. `break` is tracked with an
`in_loop` flag threaded through block analysis (a function body resets it).

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
| `statements/{if,while,loop,for,break}.lua` | One check per control-flow node |
| `expressions/init.lua` | `check_expr` dispatcher over expression rules |
| `expressions/expression_check.lua` | `ExpressionCheck` interface (`type` + `check`) |
| `expressions/{identifier,binary,call,unary}.lua` | One check per expression node |

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

Each fold rule lives in its own module, dispatched by AST node type — the same
architecture as Schematic. The driver (`init.lua`) owns the shared `FoldContext`
(constants table, expression folding, constant recording, child scopes, block
recursion); the rules stay small.

| File | Role |
|---|---|
| `init.lua` | `optimize(ast)` — driver + `FoldContext` helpers |
| `statements/init.lua` | Statement-fold dispatcher — node type → rule registry |
| `statements/statement_fold.lua` | `FoldStatement` interface (`type` + `fold`) |
| `statements/{variable,function,return,expression}.lua` | One fold per statement node |
| `statements/{if,while,loop,for}.lua` | One fold per control-flow node (bodies fold in child contexts) |
| `expressions/init.lua` | `fold_expr` dispatcher over expression rules |
| `expressions/expression_fold.lua` | `FoldExpression` interface (`type` + `fold`) |
| `expressions/{identifier,binary,call,unary}.lua` | One fold per expression node |

---

## Stage 5 — Codegen

**Input:** `AST`  
**Output:** `string` (Lua 5.0 source)  
**Files:** `src/backend/lua50/`

Walks the optimised AST and emits Lua source. A file lowers to a **class**: a
plain table `C` (named after the file; the CLI uses the filename stem, default
`Main`) whose **top-level** functions and bindings are members. **No metatables**
are emitted — `__index` lookups are avoided; members are accessed by direct
indexing. Inside a body, a reference to a member is qualified as `C.member`, while
locals and parameters stay bare (tracked by `backend/lua50/context.lua`). The
chunk is `local C = {}`, the members, then — for a program — `C.main()` and
finally `return C` (so importers and tests can read the class). See the memory
`codegen-class-table-model` for the rationale and the planned locals optimization.

### Emission rules

| AST node | Lua output |
|---|---|
| Top-level `VariableDecl` (a static member) | `C.name = <expr>` (or `C.name = nil` when valueless) |
| Top-level `FunctionDecl` (a static method) | `function C.name(params)` + indented body + `end` |
| Nested `VariableDecl` (a `local` declaration) | `local name = <expr>` (or `local name` when valueless) |
| `VariableDecl { reassign=true }` | `<target> = <expr>` (no `local`; `<target>` is `C.name` for a member, else bare) |
| Nested `FunctionDecl` | `local function name(params)` + indented body + `end` |
| `ReturnStmt { value }` | `return <expr>`, or `return` when `value=nil` |
| `ExpressionStmt { expression }` | `<expr>` |
| `IfStmt { clauses, else_body }` | `if c then … elseif c then … else … end` |
| `WhileStmt { condition, body }` | `while c do … end` |
| `LoopStmt { body }` | `while true do … end` |
| `ForStmt { init, condition, step, body }` | `do <init> while c do <body> <step> end end` (scopes the loop variable) |
| `BreakStmt` | `break` |
| `LiteralExpr { kind="number", value }` | `42` |
| `LiteralExpr { kind="string", value }` | `"hello"` (via `string.format("%q", …)`) |
| `LiteralExpr { kind="boolean", value }` | `true` / `false` |
| `IdentifierExpr { name }` | `name`, or `C.name` when it refers to a class member |
| `BinaryExpr { op, left, right }` | `left op right` (`!=`→`~=`; inner `BinaryExpr` operands parenthesised) |
| `UnaryExpr { op, operand }` | `not <operand>` (a `BinaryExpr` operand is parenthesised) |
| `CallExpr { callee, args }` | `callee(arg, arg)` (a member callee is qualified, e.g. `C.f(...)`) |

### Internal structure

| File | Role |
|---|---|
| `init.lua` | `Codegen` class — `Codegen.new(ast, class_name):generate()`; class table + members + `C.main()` + `return C` |
| `stmt.lua` | `emit_stmt(node)` (nested) and `emit_member(node)` (top-level members) |
| `expr.lua` | `emit_expr(node)` — expression → Lua string |
| `context.lua` | per-generation class name, member set, and locals scope stack; `emit_name` qualifies members |

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
