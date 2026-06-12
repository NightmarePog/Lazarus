# Lazarus – Implementation Plan

## Current State

The pipeline is **frontend-only**: source → lexer → parser → AST.
The AST is a dead end — nothing consumes it yet.

```
source  ──►  Lexer  ──►  tokens  ──►  Parser  ──►  AST  ──►  ???
```

### What exists

| Layer | Status |
|---|---|
| Lexer (`src/frontend/lexer/`) | Done — scans to `Token[]` |
| Parser (`src/frontend/parser/`) | Done — recursive descent, produces AST |
| Error system (`src/error.lua`) | Done — coloured box + source snippet |
| Sema | Not started |
| Codegen | Not started |
| CLI (`build`, `check`, `ast`) | Not started |

### What the parser currently handles

**Statements:** `let x = expr`, `let x` (uninitialised)

**Expressions:** `+`, `-`, `*`, parenthesised groups, number literals, string literals, identifiers

---

## Target Pipeline

```
source
  │
  ▼
Lexer          → Token[]
  │
  ▼
Parser         → AST (Program)
  │
  ▼
Sema           → annotated AST  ← next to build
  │
  ▼
Codegen        → Lua 5.1 source
  │
  ▼
Bundler        → single output .lua file
```

---

## Step 1 — Semantic Analysis

**Location:** `src/frontend/sema/`

Sema sits between the parser and codegen. It walks the AST and:

1. **Resolves names** — checks every `IdentifierExpr` is actually declared
2. **Tracks scope** — variables belong to the scope they are declared in
3. **Infers types** — annotates every AST node with `node._type`
4. **Rejects invalid programs** — duplicate declarations, use before declaration

### 1.1 — Type system (`sema/type.lua`)

Designed for **dynamic typing now, static typing later** (same model as TypeScript).

Current types:

```
Type.NUMBER   { kind = "number" }
Type.STRING   { kind = "string" }
Type.DYNAMIC  { kind = "dynamic" }   -- unknown at compile time
Type.NIL      { kind = "nil" }       -- uninitialised let
```

Future types slot in as new constructors alongside the singletons — no existing code changes:

```
Type.BOOL              { kind = "boolean" }
Type.union(types)      { kind = "union",    types   }
Type.class(name)       { kind = "class",    name    }
Type.func(params, ret) { kind = "function", params, returns }
```

Two operations that codegen and future checker passes use:

```
Type.lub(a, b)             -- least upper bound: result type of a binary op
                           --   number + number → number
                           --   anything + dynamic → dynamic

Type.is_assignable(from, to) -- can `from` be used where `to` expected?
                             --   dynamic is assignable to/from everything (for now)
```

### 1.2 — Scope chain (`sema/scope.lua`)

```
Scope.new(parent?)           -- nil parent = global scope
Scope:define(name, symbol)   -- error: DUPLICATE_DECLARATION if name already in this scope
Scope:lookup(name)           -- walk parent chain; nil if not found anywhere
Scope:lookup_local(name)     -- current scope only (used by define for dup check)
Scope:push()                 -- returns a new child scope (for future blocks / functions)
Scope:pop()                  -- returns parent scope
```

### 1.3 — Symbol (`sema/symbol.lua`)

```
Symbol = {
    name:  string,
    type:  Type,
    line:  integer | nil,
    col:   integer | nil,
}
```

### 1.4 — Analyser (`sema/init.lua`)

Walks the AST in source order, annotating every node with `_type`:

| Node | Rule |
|---|---|
| `LiteralExpr` | `_type = Type.NUMBER` or `Type.STRING` |
| `IdentifierExpr` | lookup in scope; `UNDEFINED_VARIABLE` if missing; `_type = symbol.type` |
| `BinaryExpr` | visit both sides; `_type = Type.lub(left._type, right._type)` |
| `VariableDecl` | visit initializer; dup-check; define in scope; `_type = initializer type or Type.NIL` |
| `ExpressionStmt` | visit inner expression; type discarded |

**Error strategy:** throw on first error (consistent with lexer/parser).
To switch to full error collection later: replace `Error.throw` calls with `table.insert(self.errors, err)` — no structural change.

### 1.5 — New error types

```
Error.Type.UNDEFINED_VARIABLE    = "UNDEFINED_VARIABLE"
Error.Type.DUPLICATE_DECLARATION = "DUPLICATE_DECLARATION"
```

---

## Step 2 — Codegen

**Location:** `src/backend/codegen.lua`

Walks the sema-annotated AST and emits Lua 5.1 source.
Reads `node._type` where it needs type information.

| AST node | Lua output |
|---|---|
| `VariableDecl { name="x", value=expr }` | `local x = <expr>` |
| `VariableDecl { name="x", value=nil }` | `local x` |
| `BinaryExpr { op="PLUS", left, right }` | `(<left> + <right>)` |
| `LiteralExpr { kind="number", value=42 }` | `42` |
| `LiteralExpr { kind="string", value="hi" }` | `"hi"` |
| `IdentifierExpr { name="foo" }` | `foo` |
| `ExpressionStmt { expression=expr }` | `<expr>` |

Output is a single `.lua` string. The bundler (step 3) writes it to disk.

---

## Step 3 — CLI + Bundler

**Location:** `src/cli.lua`, `src/backend/bundler.lua`

Three subcommands:

```
lazarus build <file>   -- full pipeline → emit .lua
lazarus check <file>   -- lex + parse + sema only (no output)
lazarus ast   <file>   -- dump AST as text (debug)
```

Bundler collects all codegen output and writes a single self-contained `.lua` file —
no `require` calls, no runtime dependencies.

---

## Language Features To Add (in order)

Before codegen is useful, the parser needs more:

| Feature | Unblocks |
|---|---|
| `/`, `%` operators | arithmetic completeness |
| `==`, `!=`, `<`, `>`, `<=`, `>=` | conditions |
| `true`, `false`, `nil` literals | boolean logic |
| Unary `-`, `not` | negation |
| `if`/`else` | branching |
| `while` | loops |
| Assignment (`x = expr`) | mutation |
| `func` + `return` | reusable logic |
| `class` | OOP (the main goal) |
| String concat `++` | Lazarus-specific |
| `@target(cc)` / `@target(oc)` | platform conditional compilation |
