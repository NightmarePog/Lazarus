# L1 — Constructor simplification (design spec)

Date: 2026-06-27
Status: approved (form chosen), pending implementation

## Goal

Remove the pervasive constructor boilerplate (`private x` decl + `constructor(x) {
.x = x }`) in two complementary forms. Both are **parser-level desugaring** into a
normal `ConstructorDecl` plus property `VariableDecl`s, so the checker, codegen,
linker, and registries need **no changes** (same approach as `@object`).

## Form A — `@auto` (synthesized constructor)

A file-head directive. The file is a normal class, but its constructor is
synthesized from the declared instance fields:

```laz
@auto
import frontend.parser.Ast
private cursor
private exprs
private depth = 0
// synthesized:
//   constructor(cursor, exprs) { .cursor = cursor  .exprs = exprs  .depth = 0 }
```

Rules:
- One constructor **param per instance field declared without a default**, in
  declaration order, each assigned `.f = f`. The param's type is the field's
  declared type (else dynamic), so injected args are type-checked.
- A field **with a default** (`private depth = 0`) is seeded by the existing
  property-default codegen — it is not a param. (No extra work: the synthesized
  `ConstructorDecl` flows through `emit_constructor`, which already seeds defaults.)
- Static fields are ignored.
- An explicit `constructor` in an `@auto` file is a parse error.
- `@auto` classes are non-generic for now (no constructor to carry `<T>`); use an
  explicit constructor for generic classes. (Flagged, accepted.)

Parsing: `@auto` parses the body like a default class, then appends a synthesized
`ConstructorDecl` (params + `FieldAssign` body) built by scanning the instance
fields.

## Form B — explicit `.params` (parameter properties)

A `.`-prefixed constructor param declares the field and assigns it; the body is
optional:

```laz
constructor(.cursor, .exprs)                 // braces optional
constructor(.a: int, .b: int) { .c = .a + .b }   // plus extra logic
```

Desugaring (parser):
- A `.name` param is a normal param named `name`, recorded as a *field param*.
- For each field param: inject a private instance-property `VariableDecl` (name +
  declared type, no default) into the class body, and prepend a `FieldAssign`
  `.name = name` to the constructor body.
- Field params are `private`, non-mutable. Need `public`/`mut`/computed init? Write
  the field + constructor explicitly.
- The body braces are optional: `constructor(.a, .b)` has an empty (then
  assignment-only) body.

## Why no downstream changes

Both forms produce, before semantic analysis:
- the same `ConstructorDecl` (with `param_types`) that `Main.collect_signatures`,
  `Schematic`, and `emit_constructor` already handle, and
- ordinary property `VariableDecl`s that `collect_members` / `build_context` /
  `collect_signatures` already treat as instance properties.

So `@auto` and `.params` are confined to `StmtParser` (+ `Keywords` already has
`AT`/`DOT`). The 3-stage self-host fixpoint is the verification.

## Testing

1. `@auto` positive — a class with injected fields + a default field; injected args
   type-checked; runs.
2. `@auto` + explicit constructor → parse error.
3. `.params` positive — `constructor(.a, .b)` (no braces) and with extra body; field
   access works; types enforced.
4. Wrong-typed injected arg → TypeError (proves param types flow).
5. Self-host fixpoint holds.
6. (Optional) migrate a few pure-DI compiler classes to `@auto`; output should be
   identical (synthesized ctor == the hand-written one), like the `@object` migration.
