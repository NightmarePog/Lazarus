# Interfaces — design spec

Date: 2026-06-27
Branch: `refactor/typed-lean-source`
Status: approved design, pending implementation plan

## Goal

Add **interfaces** to Lazarus so a dependency can be typed by a contract rather
than a concrete class. This is the real unlock for dependency-injection-for-testing:
a `FakeRepo` can be injected wherever a `Repo` contract is expected, while the
checker still verifies the fake actually fulfils the contract.

Today `constructor(r: Repo)` accepts *only* the nominal class `Repo`; a `FakeRepo`
is rejected (verified). Interfaces close that gap.

This is **Part 1** of a larger `@kind` file-directive idea. Part 1 = interfaces.
Part 2 (separate spec) = `@object` (implicit-`static` utility modules) and the
explicit `@class` default. The `@kind` parser built here is general and extensible
so later kinds are cheap to add.

## Locked decisions

| Decision | Choice |
|----------|--------|
| Conformance | **Structural** — no `implements` keyword; a type satisfies an interface if it has the required members |
| Required members | **Methods + properties** (instance, public) |
| Generics | **Generic interfaces** supported (inline form) |
| Composition | **Flat** — no `extends` |
| Declaration forms | **Both**: inline `interface Name<T> { … }` and a file-head `@interface` marker |
| Variance | **Interface-directed structural subtyping** — covariant returns work only when the requirement's return type is itself an interface; concrete class types stay nominal |
| Scope of structural subtyping | **Interface-directed only** — `compatible` stays nominal for concrete class expecteds; structural rule fires only when the *expected* type is an interface |
| Runtime | **Fully erased** — interfaces emit no code; generated Lua is byte-identical |

## Syntax

### Inline interface (supports generics)

```laz
interface Container<T> {
    get(): Option<T>
    add(x: T)
    name: str            // property requirement
}
```

An inline `interface` declaration may appear in any file's body (exactly like
`enum`). It is registered program-wide and referenced after importing the file
that declares it.

### `@interface` file-head marker (non-generic)

```laz
@interface               // must be the first token in the file
fetch(): int
save(x: int): bool
last_error: str          // property requirement
```

- Marks the **whole file** as an interface; the interface name is the filename
  (e.g. `Repo.laz` → interface `Repo`).
- Body holds **signatures only** (methods with no body) and property requirements;
  a constructor is not allowed.
- **Non-generic** — a filename cannot carry `<T>`. Use the inline form for generic
  interfaces. (Flagged consequence, accepted.)
- The parser desugars an `@interface` file into a single `InterfaceDecl` named
  after the file, so both forms flow through one downstream code path.

### General `@kind` directive

`@interface` is the first instance of a general file-head directive `@<kind>`:

- The lexer emits an `AT` token for `@`.
- Before the statement loop, the parser checks for a leading `@<identifier>`.
  - `@interface` → parse the file in interface mode (signatures only).
  - any other `@x` → `ParseError: unknown file directive '@x'`.
- This leaves `@object` / `@class` (Part 2) trivial to add: another recognized kind.

## Type system & registries

- New `Type` kind `"iface"` with factory `Type.iface_of(name, args)`.
  `Type.equals` treats `iface` head-nominally (compare name), like `class`/`enum`.
- New program-wide registry `interfaces`:
  `name → { methods, properties, type_params }`, where
  - `methods`: `name → { params, result, type_params }` (instance signatures),
  - `properties`: `name → type_node`,
  - `type_params`: the interface's `<…>` parameter names.
- `Main.collect_interfaces(ast, …)` populates `interfaces` for every linked module
  (mirrors `collect_enums`). Built before the per-module check loop.
- `Typecheck` constructor gains an `interfaces` parameter (threaded from `Main`).
- Interface modules are flagged `is_interface` on their `Module`:
  - **not** registered as classes (`collect_signatures` skips them),
  - **not** emitted by codegen.

## Name resolution & checker

### `resolve(t)` (annotation node → Type)

Add, before the class branch:

```
if .interfaces.has(name) {
    return Type.iface_of(name, .resolve_args(t, name))
}
```

`declared_arity(name)` returns the interface's `type_params` count so explicit
`<…>` arity is checked.

### Conformance = interface-directed structural subtyping (the heart)

`compatible(expected, actual)`:

- `expected` / `actual` is `dynamic` or a type `var` → `true` (defer; lenient policy).
- **`expected.kind == "iface"`** → `satisfies(expected, actual)`.
- otherwise → existing nominal rule (`equals` head + `args_compatible`).

`satisfies(I, actual)` where `I = iface name<A>`:

1. `actual` is `dynamic` / `var` / a class not in the registry → `true` (defer).
2. `actual` is the **same** interface (`iface`, same name) → `args_compatible(A, actual.params)`.
3. `actual` is a class `C<B>` (or another interface): structural check.
   - Build interface subst `σ_I`: `I.type_params → A`.
   - Build actual subst `σ_C`: `C.type_params → B`.
   - For **each** required method `m` of `I`:
     - `C` must have `m` as a **non-static instance** method (else fail
       `"<C> does not satisfy <I>: missing method 'm'"`).
     - arity must match (else fail with the count).
     - for each param `i` and the return type: check
       `compatible( resolve(I.m.type_i under σ_I), resolve(C.m.type_i under σ_C) )`.
   - For **each** required property `p` of `I`:
     - `C` must have a public instance property `p`; check
       `compatible( resolve(I.p under σ_I), resolve(C.p under σ_C) )`.
   - All pass → `true`; first miss → precise `TypeError`.

Because `compatible` is itself interface-directed, a requirement whose **return
type is an interface** accepts any structurally-conforming type — i.e. **covariant
returns toward interfaces, for free**. Concrete return types still match nominally.
Param types are checked with the same `compatible` relation (lenient/invariant for
concrete types; structural when an interface is involved) — consistent with how the
rest of the checker already treats arguments.

**Termination — visited-pair guard.** Structural subtyping is recursive (a
requirement's interface-typed return triggers another `satisfies`). A coinductive
guard records in-progress `(interface-name, actual-name)` pairs and treats a
re-entrant pair as `true`, so mutually-referential interfaces terminate.

### Guards

- Constructing or calling an interface (`Repo(...)`, `Repo.x`) →
  `TypeError: cannot construct interface 'Repo'`. `Schematic` seeds interface
  names into the root scope so the message is this clean error, not
  "undeclared identifier".

## Codegen

- `StmtEmitter` returns `""` for an `InterfaceDecl` (erased).
- `@interface` modules emit nothing and are absent from the class output.
- Net effect: **generated Lua is byte-identical** to pre-feature output for any
  program that does not *use* interfaces, and a program that uses them pays zero
  runtime cost (interfaces are a pure compile-time contract). The performance model
  (tagged-table primitives, no metatables) is untouched.

## Files touched (for the plan)

- `compiler/frontend/lexer/Keywords.laz` — `interface` keyword; `@` → `AT`.
- `compiler/frontend/lexer/Lexer.laz` — emit `AT` token (if not table-driven).
- `compiler/frontend/parser/StmtParser.laz` — `parse_interface` (inline),
  `@interface` file-head handling, signature/property-requirement parsers.
- `compiler/frontend/parser/Ast.laz` — `interface_decl` node (+ signature/property
  node shapes).
- `compiler/frontend/typecheck/Type.laz` — `iface_of`, `equals` for `iface`.
- `compiler/frontend/typecheck/Typecheck.laz` — `interfaces` field/param,
  `resolve` branch, `declared_arity` branch, `satisfies` + visited-pair guard,
  `compatible` dispatch, construction/call guards.
- `compiler/frontend/schematic/Schematic.laz` — seed interface names.
- `compiler/backend/StmtEmitter.laz` — erase `InterfaceDecl`.
- `compiler/backend/linker/*` + `compiler/Main.laz` — `is_interface` module flag,
  `collect_interfaces`, skip class registration/codegen for interface modules,
  pass `interfaces` to `Typecheck`.

## Bootstrap / self-host

The compiler's own source does **not** use interface syntax in Part 1, so the seed
compiler never has to parse `interface`/`@`. The new lexer/parser/checker code is
ordinary `.laz` (new branches, string compares) the seed compiles fine. Adding an
`interfaces` argument to `Typecheck(...)` is a plain extra call argument. Therefore
`bin/build-compiler`'s 3-stage byte-fixpoint must continue to pass unchanged — the
feature is purely additive.

## Testing

End-to-end `.laz` probes (the project's testing model: self-host fixpoint +
program probes):

1. **Positive DI** — `interface Repo { fetch(): int }`; `Repo.laz` and `FakeRepo.laz`
   both have `fetch(): int`; both inject through `constructor(r: Repo)`; program runs.
2. **Missing method** — a class lacking `fetch` injected where `Repo` expected → error.
3. **Wrong signature** — `fetch(): str` where `fetch(): int` required → error.
4. **Property requirement** — interface requires `name: str`; class missing it / wrong
   type → error; matching class → OK.
5. **Generic** — `interface Container<T>`; `Box<int>` satisfies `Container<int>`,
   `Box<str>` does not.
6. **Covariant return** — interface method returning an interface, satisfied by a
   class whose method returns a more-specific (structurally-conforming) type → OK.
7. **Cyclic interfaces** — mutually-referential interfaces terminate (no hang).
8. **`@interface` file form** — a `@interface` file used as a contract works the
   same as an inline interface.
9. **Erasure** — `diff` generated Lua of a program before/after adding an unused
   interface: identical; interface-using program contains no interface artifacts.
10. **Self-host** — `bin/build-compiler` 3-stage fixpoint passes.

## Out of scope (Part 1)

- `@object`, `@class`, `@enum`-file directives (Part 2 / later).
- `extends` / interface composition.
- Generic `@interface` *file* form (inline form covers generics).
- Universal (non-interface-directed) structural subtyping.
- Co/contravariance beyond the interface-directed return covariance described.
