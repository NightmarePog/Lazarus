# Lazarus — Interfaces

An **interface** is a structural contract: a set of method signatures and property
requirements. Any class that has those members satisfies the interface — there is
no `implements` keyword. Interfaces exist only at compile time; they emit **no**
Lua and add **zero** runtime cost.

The main use is dependency injection: type a collaborator by an interface so a real
or a fake implementation can be injected interchangeably, while the checker still
verifies each one fulfils the contract.

## Declaring an interface

Two forms, both fine to mix in a project.

### Inline — in any file's body (like `enum`)

```laz
interface Repo {
    fetch(): int
    save(x: int): bool
    last_error: str            // property requirement
}

interface Container<T> {       // generic
    get(): Option<T>
    add(x: T)
}
```

A method line is a signature with **no body**. A `name: Type` line is a property
requirement. A file may declare interfaces alongside its own class members.

### `#interface` file — the whole file is one interface

```laz
#interface                     // must be the first token in the file
import Animal                  // imports are allowed
make(): Animal
sound(): int
```

The interface is named after the file (`Maker.laz` → `Maker`). The body is
signatures and property requirements only — no constructor, no method bodies.
`#interface` files are **non-generic**; use the inline form for `<T>`.

`#interface` is one case of a general `#kind` file-head directive; an unknown
`#x` is a parse error.

## Using an interface

Reference it anywhere a type is expected (after importing the file that declares
it):

```laz
// Service.laz
import Repo
private repo: Repo
constructor(r: Repo) { .repo = r }     // inject any class that satisfies Repo
run(): int { return .repo.fetch() }    // calls are typed from the contract
```

```laz
import Service
import RealRepo        // has fetch(): int, save(x: int): bool, last_error: str
import FakeRepo        // same shape, different behaviour
constructor() {
    Service(RealRepo()).run()
    Service(FakeRepo()).run()          // both accepted
}
```

## Conformance rules

A class satisfies an interface when, for every requirement:

- it has the **method** as a non-static instance method, with the same arity and
  compatible parameter and return types;
- it has the **property** as a public instance property of a compatible type.

Generic interfaces unify type arguments on both sides: `Box<int>` satisfies
`Container<int>` but not `Container<str>`.

Conformance is **structural and interface-directed**: the structural rule fires
only when the *expected* type is an interface. A concrete class annotation
(`r: Repo` where `Repo` is a class) still requires that exact class.

### Covariant returns (toward interfaces)

When a requirement's return type is itself an interface, a class whose method
returns a more specific (conforming) type satisfies it:

```laz
#interface
make(): Animal          // Animal is an interface

// CatMaker.make returns the concrete Cat, which satisfies Animal — accepted.
make(): Cat { return Cat() }
```

## Errors

- A class missing a member, or with an incompatible signature:
  `Box does not satisfy Container<int>: method 'get' returns Option<str>, expected Option<int>`
- Constructing an interface: `cannot construct interface 'Repo'`.

## Gotchas

- **Reserved method names.** A user method named like a built-in collection/Option/
  Result method is lowered to the built-in (`__lz_*`) and will misbehave at runtime.
  Avoid: `get`, `pop`, `push`, `len`, `has`, `unwrap`, `unwrap_or`,
  `is_some`/`is_none`/`is_ok`/`is_err`, `error`.
- **An unresolved type name degrades to `dynamic`.** If a file uses a type it does
  not import, the annotation is silently treated as `dynamic` (no check). Import the
  declaring file for the annotation to be enforced.

See `docs/superpowers/specs/2026-06-27-interfaces-design.md` for the full design.
