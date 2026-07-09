# Lazarus – Compiler Pipeline

## Overview

```
source: string
  │
  ▼
Lexer                   compiler/frontend/lexer/
  │  List<Token>
  ▼
Parser                  compiler/frontend/parser/
  │  AST (Program node)
  ▼
Expander                compiler/Expander.class.laz
  │  AST (macros applied)
  ▼
Schematic               compiler/frontend/schematic/
  │  AST (names resolved, scopes verified)
  ▼
Typecheck               compiler/frontend/typecheck/
  │  AST (types checked)
  ▼
Optimizer               compiler/frontend/optimizer/
  │  AST (constants folded/propagated)
  ▼
Codegen                 compiler/backend/
  │  string (Lua 5.1 class block)
  ▼
Bundler                 compiler/backend/Bundler.class.laz
  │  string (complete Lua program)
  ▼
Lua 5.1 source
```

The entry point is `compiler/Main.class.laz`. The Linker
(`compiler/backend/linker/`) resolves import chains and builds the ordered
module list before any pipeline stage runs; the remaining stages run on each
module in dependency order.

To add a new language feature, follow [`adding-features.md`](adding-features.md)
— the stage-by-stage recipe.

---

## Pre-pass — Linker

**Input:** entry file path  
**Output:** `List<Module>` in topological dependency order  
**Files:** `compiler/backend/linker/`

Follows `import` statements recursively, reads each `.laz` file, lexes and
parses it, and returns the modules sorted so each dependency comes before its
dependents. Prebuilt `.lua` libraries (those with a `LAZARUS_META` header) are
loaded directly without recompilation.

File kinds are determined by filename suffix:

| Suffix | Kind | Notes |
|---|---|---|
| `.class.laz` | class | default; has instances and a constructor |
| `.object.laz` | object | static-only; no instances, no constructor |
| `.trait.laz` | trait | interface declaration |
| `.macro.laz` | macro | macro handler; excluded from the output bundle |

---

## Stage 1 — Lexer

**Input:** `string` (source text)  
**Output:** `List<Token>`  
**Files:** `compiler/frontend/lexer/`

Single-pass scanner. Walks the source byte by byte and emits a flat token list.
Whitespace and comments are discarded. Every token records `line` and `column`
so downstream errors can point at source text.

### Token fields

| Field | Type | Description |
|---|---|---|
| `kind` | `str` | Symbolic kind (`"NUMBER"`, `"IDENTIFIER"`, `"PLUS"`, …) |
| `value` | `str` | Raw source text |
| `line` | `int` | 1-based source line |
| `column` | `int` | 1-based source column |

### Selected token kinds

| Kind | Source text |
|---|---|
| `PRIVATE` / `PUBLIC` | `private` / `public` |
| `MUTABLE` | `mut` |
| `STATIC` | `static` |
| `CONSTRUCTOR` | `constructor` |
| `RETURN` | `return` |
| `IDENTIFIER` | any `[a-zA-Z_][a-zA-Z0-9_]*` not matched as a keyword |
| `NUMBER` | integer or float literal |
| `STRING` | double-quoted string literal |
| `ASSIGN` | `=` |
| `PLUS` / `MINUS` / `STAR` / `SLASH` / `MODULO` / `POWER` | `+` `-` `*` `/` `%` `^` |
| `CONCAT` | `++` (string concatenation; lowers to Lua `..`) |
| `LEFT_BRACKET` / `RIGHT_BRACKET` | `(` `)` |
| `BODY_START` / `BODY_END` | `{` `}` |
| `LEFT_SQUARE` / `RIGHT_SQUARE` | `[` `]` |
| `COMMA` / `COLON` / `DOT` | `,` `:` `.` |
| `ARROW` | `->` |
| `LESS` / `GREATER` | `<` `>` |
| `IF` `ELSE` `WHILE` `LOOP` `FOR` `BREAK` | control-flow keywords |
| `MATCH` | `match` keyword |
| `ENUM` `TRAIT` `IMPLEMENT` `EXTERN` `IMPORT` `LUA` `PLATFORM` | declaration keywords |
| `TRUE` / `FALSE` | boolean literals |
| `AND` / `OR` / `NOT` | logical operators |
| `EQ` `NEQ` `LESS_EQUAL` `GREATER_EQUAL` | `==` `!=` `<=` `>=` |
| `PLUS_ASSIGN` `MINUS_ASSIGN` `STAR_ASSIGN` `SLASH_ASSIGN` | `+=` `-=` `*=` `/=` |

Multi-character operators use **maximal munch**.

### Files

| File | Role |
|---|---|
| `Lexer.class.laz` | `Lexer(source).scan()` — the main scanner |
| `Token.class.laz` | `Token` value type |
| `Keywords.object.laz` | keyword map: source text → token kind |
| `Char.object.laz` | character classification helpers |

---

## Stage 2 — Parser

**Input:** `List<Token>`, source string, file kind  
**Output:** `Node` (a `Program` node)  
**Files:** `compiler/frontend/parser/`

Recursive-descent parser. Produces an AST using the `Ast` factory. Statement
and expression parsing are split across `StmtParser` and `ExprParser`; type
expression parsing lives in `TypeParser`.

### AST structure

Every node is a `Node` instance whose shape is documented in `Ast.object.laz`.
The root is always `Program { body: List<Node> }`.

**Top-level declaration nodes**

| Node | Key fields | Source |
|---|---|---|
| `ImportDecl` | `segments`, `name` | `import path.To.Thing` |
| `VariableDecl` | `name`, `value`, `visibility`, `mutable`, `is_static`, `type` | `private x: int = 3` |
| `FunctionDecl` | `name`, `params`, `param_types`, `return_type`, `body`, `is_static`, `visibility`, `type_params` | `public fn(x: int): str { … }` |
| `ConstructorDecl` | `params`, `param_types`, `field_params`, `body` | `constructor(.x: int)` |
| `EnumDecl` | `name`, `variants`, `type_params` | `enum Color { Red, Green, Blue }` |
| `TraitDecl` | `name`, `methods`, `properties`, `type_params` | `trait Show { … }` |
| `ImplementDecl` | `trait_name`, `class_name`, `methods` | `implement Show for Foo { … }` |
| `ExternDecl` | `name`, `params`, `return_type`, `target` | `extern fn(): str = "os.time"` |

**Statement nodes**

| Node | Key fields | Source |
|---|---|---|
| `ReturnStmt` | `value` | `return expr` |
| `IfStmt` | `clauses`, `else_body` | `if c { } else if d { } else { }` |
| `WhileStmt` | `condition`, `body` | `while c { … }` |
| `LoopStmt` | `body` | `loop { … }` |
| `ForStmt` | `iter_name`, `iter_expr`, `body` | `for x in list { … }` |
| `MatchStmt` / `MatchExpr` | `subject`, `arms` | `match x { Foo(v) => { … } }` |
| `BreakStmt` | — | `break` |
| `FieldAssign` | `target`, `value` | `.x = 3` |

**Expression nodes** (selected)

| Node | Key fields | Example |
|---|---|---|
| `Literal` | `kind`, `value` | `42`, `"hi"`, `true` |
| `Identifier` | `name` | `foo` |
| `Binary` | `op`, `left`, `right` | `a + b` |
| `Unary` | `op`, `operand` | `not done` |
| `Call` | `callee`, `args`, `type_args` | `f(a, b)` |
| `Member` | `object`, `field` | `.x`, `obj.field` |
| `SelfExpr` | — | implicit receiver |
| `ListExpr` | `items` | `[1, 2, 3]` |
| `MapExpr` | `pairs` | `["a": 1]` |
| `ListComp` | `expr`, `iter_name`, `iter_expr`, `condition` | `[f(x) for x in xs if p(x)]` |
| `FnExpr` | `params`, `body` | `(x) => x + 1` |
| `Index` | `object`, `index` | `arr[i]` |

**Type nodes**

| Node | Fields | Source |
|---|---|---|
| `TypeName` | `name`, `args` | `List<str>`, `int` |
| `TypeFn` | `params`, `result` | `(int, str) -> bool` |

### Files

| File | Role |
|---|---|
| `Parser.class.laz` | Entry point: `Parser(tokens, source, kind).parse()` |
| `StmtParser.class.laz` | Statement and declaration grammar |
| `ExprParser.class.laz` | Expression grammar (precedence climbing) |
| `TypeParser.class.laz` | Type expression grammar |
| `TokenCursor.class.laz` | Token stream with lookahead, consume, and error recovery |
| `Ast.object.laz` | Factory: one named constructor per node kind |
| `Node.class.laz` | The `Node` type: `kind` + attribute map |

---

## Pre-stage — Expander

**Input:** `Node` (parsed AST), module list  
**Output:** `Node` (AST with macro-injected members)  
**File:** `compiler/Expander.class.laz`

Applies macro modifiers to declarations. A macro modifier (e.g. `Debug
constructor(…)`) attaches a `macro_modifiers` list to the node; the Expander
loads the handler module, calls its `apply` (or named) method, and splices the
returned nodes into the class body.

Macro handlers live in `.macro.laz` files and import `std.macro.Macro` for
context and node-building helpers.

---

## Stage 3 — Schematic

**Input:** `Node` (AST)  
**Output:** `Node` (same, validated)  
**Files:** `compiler/frontend/schematic/`

Single-pass semantic checker. Maintains a lexical scope stack (`Scope`) and a
`Frame` (tracks whether we are inside a function/loop/constructor). Checks:

- Duplicate declarations in the same scope
- Undeclared identifiers
- Top-level bindings must declare visibility (`private`/`public`)
- Immutable binding reassignment
- `break` / `return` placement rules
- `self` / `.field` outside an instance method
- Unknown instance members
- Naming conventions (`snake_case` for values)
- Enum variant usage and arity
- `extern` platform annotations

### Files

| File | Role |
|---|---|
| `Schematic.object.laz` | Entry: `Schematic.analyze(ast, source, class_name, imports, …)` |
| `StmtChecker.class.laz` | Statement-level rules |
| `ExprChecker.class.laz` | Expression-level rules |
| `Scope.class.laz` | Lexical scope: `declare`, `lookup`, child scopes |
| `Frame.class.laz` | Control-flow context flags |
| `Symbol.class.laz` | Per-binding record: `kind`, `mutable`, `noncallable` |
| `Naming.object.laz` | Naming convention checks |
| `Callability.object.laz` | Determines whether an expression is provably non-callable |
| `Booleanity.object.laz` | Determines whether a condition is always-true/false |

---

## Stage 4 — Typecheck

**Input:** `Node` (AST), module signatures, enum registries  
**Output:** `Node` (same, type-annotated)  
**Files:** `compiler/frontend/typecheck/`

Bidirectional type inference and checking. Resolves generic type parameters,
verifies call argument types, checks field access, and validates enum pattern
matching. Method calls on known classes are resolved against their signatures.

| File | Role |
|---|---|
| `Typecheck.class.laz` | Entry: `Typecheck(source, class_name, …).check(ast)` |
| `Type.class.laz` | Type value: `kind`, `name`, `params`, `result` |

---

## Stage 5 — Optimizer

**Input:** `Node` (AST)  
**Output:** `Node` (mutated in place)  
**Files:** `compiler/frontend/optimizer/`

Three optimization levels control which passes run:

| Flag | Level | Passes |
|---|---|---|
| `-O0` | 0 | none |
| `-O1` | 1 | constant propagation + folding |
| `-O2` | 2 | O1 + method-call inlining (e.g. `is_some` → `!= "None"`) |
| `-Os` | 3 | O2 + name mangling (short identifiers) |

**Constant propagation** — an immutable binding with a foldable initialiser is
entered into the `Constants` table; later `Identifier` references are replaced
with the literal.

**Constant folding** — `Binary` nodes with two literal operands are evaluated at
compile time.

**Algebraic simplification** — `x + 0`, `x * 1`, `x * 0`, `x - 0` are
reduced.

**Method inlining** (O2) — zero-arg calls like `.is_some()` are replaced with a
direct `!= "None"` comparison.

**Name mangling** (Os) — all class names, method names, and local names are
replaced with minimal identifiers (`a`, `b`, … `aa`, `ab`, …); class names use
uppercase letters to avoid collision with lowercase locals.

### Files

| File | Role |
|---|---|
| `Optimizer.class.laz` | Entry: `Optimizer(level).optimize(ast, class_name)` |
| `ExprFolder.class.laz` | Expression-level folding and inlining |
| `StmtFolder.class.laz` | Statement-level traversal |
| `Constants.class.laz` | Constant table for propagation |

---

## Stage 6 — Codegen

**Input:** `Node` (AST per module)  
**Output:** `string` (Lua 5.1 class table block)  
**Files:** `compiler/backend/`

Lowers a module to a Lua `local C = {}` class table. Each module becomes one
class block; the Bundler assembles them.

**Class model:** instance methods take an implicit `self` first parameter
(`function C.name(self, …)`). Instance method calls emit receiver-passing
dispatch (`C.m(obj, args)`). Properties are initialised in `C.new`. Static
members are `C.name = …`.

**Emission rules** (selected):

| AST node | Lua output |
|---|---|
| Non-static visibility `VariableDecl` | `self.name = <default>` in `C.new` |
| Static `VariableDecl` | `C.name = <expr>` |
| Instance `FunctionDecl` | `function C.name(self, params) … end` |
| Static `FunctionDecl` | `function C.name(params) … end` |
| `ConstructorDecl` | `function C.new(params) local self = {} … return self end` |
| `MatchStmt` / `MatchExpr` | tagged union dispatch on `.__tag` |
| `ForStmt` (for-in) | `for _, v in List.__lz_each(iter) do … end` |
| `ListExpr` | `List.__lz_list({…})` |
| `MapExpr` | `Map.__lz_map({…})` |

### Files

| File | Role |
|---|---|
| `Codegen.class.laz` | Entry: constructs `CgContext`, delegates to emitters |
| `CgContext.class.laz` | Per-class name table, local scope, mangler interface |
| `StmtEmitter.class.laz` | Statement → Lua string |
| `ExprEmitter.class.laz` | Expression → Lua string |
| `Text.object.laz` | String helpers (join, indent, newline) |
| `Mangler.class.laz` | Short-identifier generator for `-Os` |

---

## Post-pass — Bundler

**Input:** `List<Module>` (each with its class block)  
**Output:** `string` (complete Lua program)  
**File:** `compiler/backend/Bundler.class.laz`

Concatenates class blocks in dependency order, prepends the `__lz_*` runtime
prelude when collections or Options are used, appends the entry-point call
`return EntryClass.new(...)`, and writes the result. Also handles prebuilt (`.lua`)
library modules by inserting their source verbatim.

The `LAZARUS_META` header (written by `MetaEmitter`) records the class
signature so the file can be imported as a prebuilt library without
recompilation.

---

## Registry pass — Collector

**Input:** module AST  
**Output:** populates shared maps for later analysis passes  
**File:** `compiler/frontend/Collector.object.laz`

Walks every module's AST before Schematic/Typecheck and builds three
program-wide registries:

- **`collect_enums`** — enum name → variant list, variant → owner, arity, payload fields, type params
- **`collect_signatures`** — class name → `{fields, methods, ctor, ctor_names, type_params}`
- **`collect_traits`** — trait name → `{methods, properties, type_params}`

These registries are passed into `Schematic.analyze` and `Typecheck.check`
so they can resolve cross-module references.

---

## Error system

Errors are instances of `Error.class.laz`. The parse cursor's `flush()` method
renders them as coloured boxes (in interactive mode) or JSON lines (in
`--check` mode, used by LSP tooling).

```
╭─ Error ──────────────────────────────
│ Type: SemanticError
│ Location: Foo.class.laz:12:5
│
│  12 │   foo.bar()
│          ^^^
╰──────────────────────────────────────
```
