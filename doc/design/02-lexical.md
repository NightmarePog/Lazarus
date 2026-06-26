# 02 — Lexical & Surface Syntax

The lexical layer the rest of the language is built on. Most of these are new
tokens the current lexer does not yet emit; see
[08-implementation.md](08-implementation.md) for how they are added.

## Comments

```
// line comment
/* block
   comment */
```

Block comments do not nest in v1. Comments are discarded by the lexer and carry
no semantic meaning.

## Identifiers and enforced casing

Identifiers match `[A-Za-z_][A-Za-z0-9_]*`. **Casing is enforced by the
compiler** (a `SEMANTIC_ERROR`, not a warning):

| Kind | Convention | Example |
|---|---|---|
| Classes (file names), enums, enum variants, traits | `PascalCase` | `LineBuffer`, `Status.Ok`, `Show` |
| Functions, methods, fields, variables | `snake_case` | `read_line`, `cursor_x` |

```
fn read_line() { ... }       // ok
fn ReadLine() { ... }        // ERROR: function must be snake_case
struct lineBuffer { ... }    // ERROR: 'struct' does not exist anyway
```

A file named `Vec2.laz` therefore defines class `Vec2`; a file whose name is not
valid `PascalCase` is rejected.

## Literals

```
42            // int
3.14          // float
true  false   // bool
"hello"       // str
[1, 2, 3]     // list  [int]
{ "a": 1 }    // map   {str: int}
```

There is **no `nil` literal** — use `Option` (see
[04-types-and-data.md](04-types-and-data.md)).

### Strings

Double-quoted, with escapes `\n \t \" \\` and **interpolation** using `{ }`:

```
name = "al"
n    = 3
msg  = "hi {name}, you have {n} items"
```

Interpolation lowers to `..` concatenation; `{` is written `\{` when literal.
The interpolated expression must be `str`-typed already or explicitly converted —
`++`/interpolation never coerces numbers silently (see operators below).

## Operators

### Arithmetic (numeric only)

| Op | Meaning | Notes |
|---|---|---|
| `+` `-` `*` | add / sub / mul | numeric operands only |
| `/` | division | float division (native in 5.0) |
| `%` | modulo | synthesized on 5.0 |
| `-x` | unary negation | |
| `^` | exponent | native in 5.0 |

`+` is **strictly numeric**. Mixing `int` and `float` without an explicit
conversion is a type error (see 04).

### String

| Op | Meaning |
|---|---|
| `++` | string concatenation (`str ++ str`) |

### Comparison and logic

| Op | Meaning |
|---|---|
| `==` `!=` | equality / inequality |
| `<` `<=` `>` `>=` | ordering |
| `and` `or` `not` | logical (word forms), short-circuiting |

`and`/`or`/`not` are keywords, not symbols. Conditions are `bool`-typed; there is
no truthiness coercion (`if x` requires `x: bool`).

### Assignment

| Op | Meaning |
|---|---|
| `=` | bind / reassign |
| `+=` `-=` `*=` `/=` | compound assignment (`x op= v` ≡ `x = x op v`) |

## Bindings

A binding is **immutable by default**; `mut` makes it reassignable. There is no
`let` keyword — the name and `=` are enough.

```
base = 10            // immutable
mut total = 0        // mutable
total += base        // ok
base = 5             // ERROR: cannot assign to immutable binding
```

The same form is used for **local variables** inside functions and for **class
fields** at the top level of a file (see [03-classes.md](03-classes.md)); a field
additionally may carry a type annotation and a `pub`/visibility modifier.

A bare `name = expr` is a *declaration* the first time the name appears in a
scope and a *reassignment* afterward; Schematic decides which, and rejects
reassignment of an immutable binding.

## Visibility

Everything is **private to its class by default**. `pub` exports an item so other
files may use it after importing the class.

```
pub fn draw(self) { ... }    // visible to importers
fn helper(self) { ... }      // private
pub x: int = 0               // public field
y: int = 0                   // private field
```

`pub` applies to fields, methods, enums, traits, and `init` (a `pub init`
means other files may construct the class; a private `init` makes it
constructible only from within its own file).

## Keyword list (v1)

```
pub  mut  fn  return  self  static  init  extends  override  super  abstract
import  extern  lua  as
if  else  while  loop  for  break  match
enum  trait  impl
and  or  not  true  false
int  float  str  bool        // primitive type names (contextual)
```

`Option`, `Some`, `None` are built-in identifiers provided by the prelude, not
reserved keywords. `Result` is **not** built-in: it is provided by the stdlib as
typed classes (`ResultBool`/`ResultString`/`ResultInt`) — see
[04-types-and-data.md](04-types-and-data.md).
