# `@object` directive — design spec

Date: 2026-06-27
Branch: `refactor/typed-lean-source`
Status: approved design, pending implementation

## Goal

Add a file-head `@object` directive that makes a file a **static module**: every
top-level member is implicitly `static`, so the ~11 all-static utility modules stop
writing `static` on every method. This is **Part 2** of the `@kind` directive
introduced with interfaces (Part 1).

## Locked decisions

| Decision | Choice |
|----------|--------|
| `static` keyword inside `@object` | **Forbidden** (it's implied) — parse error |
| `constructor` inside `@object` | **Error** — an object has no instances |
| Migration of the 11 util modules | **Now**, in this part |

## Core insight

An `@object` file forces `is_static = true` on every top-level member. A
fully-static module already lowers to `local C = {}` + `function C.method(...)` with
no instance machinery, so migrating such a module yields the **identical AST** and
therefore **identical generated Lua**. The 3-stage self-host fixpoint is preserved
by construction — that is the migration's verification.

## Syntax

```laz
@object                         // must be the first token in the file
import frontend.parser.Node     // imports allowed (lifted by the linker)

join(xs, sep): str { … }        // implicitly static; no `static` keyword
private helper(): int { … }     // private static method
private words = [ … ]           // static field (lookup table / constant)
```

`@object` is detected as `@` followed by the identifier `object` — **not** a new
keyword, because `object` is already used as a local variable name in the compiler
(`mut object = member.child("object")`). `@interface` continues to use the
`interface` keyword. The `@kind` dispatch:

- `@interface` → interface body
- `@object` → object body
- any other `@x` → `ParseError: unknown file directive '@x'`

## Rules

- A `static` keyword inside an `@object` file → `ParseError` (`'static' is implied
  in an @object file; remove it`).
- A `constructor` inside an `@object` file → `ParseError` (`an @object file has no
  instances; remove the constructor`).
- A member with a visibility but no initialiser still requires `=` (it is a static
  field, never an instance property — there are no instances).
- Imports are parsed and lifted exactly as in an `@interface` file.

## Implementation

Parser-only; no checker, codegen, or linker changes (static members already flow
through every later stage; `@object` files are ordinary all-static classes and need
no `is_interface`-style flag).

- `compiler/frontend/parser/StmtParser.laz`
  - Generalise the `@` dispatch into `parse_file_directive`: `@interface` (existing
    body parser) vs `@object` (new) vs error.
  - `parse_object_body`: loop to end of file; parse `import` lines into the program
    body; otherwise `parse_object_member`.
  - `parse_object_member`: optional `private`/`public`; reject `STATIC` and
    `CONSTRUCTOR`; then parse a method (`parse_method(visibility, true)`) or a
    binding (`parse_binding(visibility, mutable, …, true)`) — always `is_static`.
  - The output is a normal `Program` of static members (no new node kind).

## Migration

Add `@object` and strip every `static` keyword from the 11 modules:
`Text`, `Path`, `Char`, `Naming`, `Keywords`, `Booleanity`, `Callability`,
`Runtime`, `Meta`, `Ast`, `Schematic` (all surveyed: only static methods + static
fields, no constructors, no instance members). Each becomes:

```laz
@object
<imports…>
<members without `static`>
```

Because the AST is unchanged, generated Lua is unchanged.

## Testing

1. `@object` positive — a static module called as `Obj.method(...)` compiles and
   runs.
2. `static` inside `@object` → parse error.
3. `constructor` inside `@object` → parse error.
4. Static field in `@object` (a lookup table) works.
5. **Decisive:** `bin/build-compiler` 3-stage fixpoint passes after migrating all
   11 modules (proves identical output).

## Out of scope

- `@class` (the explicit default no-op) — trivial later if wanted.
- `@enum` file form — low value (inline `enum` exists).
- Enforcing absence of `self`/`.field` inside `@object` (would be broken code
  anyway; not worth a dedicated check now).
