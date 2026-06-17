# 03 — Classes

A `.laz` file **is** a class. The filename is the class name. There is no `class`
keyword and no surrounding braces — the top level of the file is the class body.

## Anatomy of a class file

The top level of a file may contain, in any order:

- **instance fields** — `name: Type [= default]`
- **a constructor** — `init(params) { ... }`
- **instance methods** — `fn name(self, ...) [: Ret] { ... }`
- **static members** — a `static { ... }` block
- **inheritance / trait headers** — `extends Parent`, `impl TraitA, TraitB`
- **nested enums** — `enum Name { ... }`
- **nested traits** — `trait Name { ... }`
- **imports** — `import Other`

```
// Sprite.laz  ->  class Sprite
import Vec2

extends Actor               // single base class
impl Show, Drawable         // traits this class satisfies

pub pos: Vec2               // instance field, no default (init must set it)
mut hp: int = 100           // mutable instance field with a default

static {
    count: int = 0          // shared across all instances
    fn total(): int { return count }
}

init(pos: Vec2) {
    self.pos = pos
    Sprite.count += 1       // static access from inside
}

pub fn show(self): str {    // satisfies trait Show
    return "sprite at ({self.pos.x}, {self.pos.y})"
}

override fn update(self) {  // overrides Actor.update
    super.update()
    self.hp -= 1
}
```

## Instance fields

Declared as typed bindings at the top level:

```
pub x: int = 0     // public, mutable? No -> immutable by default
mut y: int = 0     // mutable
name: str          // private, no default -> init must assign it
```

Rules:
- **Immutable by default.** `x: int` is read-only after construction. `mut x: int`
  permits reassignment (including `self.x = ...` inside methods and `+=`).
- **Private by default.** `pub` exposes a field to importers.
- **Defaults allowed.** A field with `= expr` may be omitted by `init`; a field
  without a default **must** be assigned in `init` (Schematic enforces it).
- Field types are required (no inference for fields).

## Constructor: `init`

A class has **one** `init` block. Construction is a call on the class name:

```
init(pos: Vec2, hp: int = 100) {   // default param values allowed
    self.pos = pos
    self.hp = hp
}

s = Sprite(origin)        // hp defaults to 100
s2 = Sprite(origin, 50)
```

- `init` has no return type and returns the new instance implicitly.
- Inside `init`, `self` refers to the fresh instance; every field without a
  default must be assigned before `init` ends.
- For alternative constructors, write **static factory functions** that call
  `init` (there is only one `init`):

```
static {
    fn at_origin(): Sprite { return Sprite(Vec2(0, 0)) }
}
s = Sprite.at_origin()
```

- A class with an **abstract method** (below) cannot be constructed; `init`
  on such a class is only callable by subclasses via `super`.

## Methods and `self`

A function with a `self` first parameter is an **instance method**; without it,
it is **static** (and belongs in the `static` block — see below).

```
pub fn dist(self): float { ... }
```

Calls use an **implicit receiver** — you do not pass `self` at the call site:

```
d = s.dist()          // not s.dist(s)
self.update()         // from inside another method
super.update()        // parent's version
```

This lowers to Lua's `:` method-call syntax. See
[08-implementation.md](08-implementation.md).

## Static members

Shared (per-class, not per-instance) state and functions live in a `static`
block:

```
static {
    count: int = 0
    max: int = 1000
    fn reset() { count = 0 }
}
```

- Static fields follow the same immutable-by-default / `pub` rules.
- Static functions have no `self`.
- Inside the class, reference statics bare (`count`) or qualified (`Sprite.count`);
  from another file, qualified after import (`Sprite.total()`).
- **The entry point** `fn main()` is just a static function with no `self` in the
  file you build (it need not be inside the `static { }` block — a top-level
  `self`-less `fn` is static by definition; the block is for grouping shared
  state). See [06-modules-and-linking.md](06-modules-and-linking.md).

## Inheritance

Single inheritance via a top-of-file `extends`:

```
extends Actor
```

- A subclass inherits the parent's fields and methods.
- Overriding a parent method **requires** the `override` keyword; `override` on a
  method that does not actually override (typo, wrong signature) is a
  `SEMANTIC_ERROR`, and shadowing without `override` is also an error. This
  catches the classic accidental-override bug.
- `super.method()` calls the parent's implementation.
- The constructor chain: a subclass `init` should call `super(...)` to run the
  parent constructor (exact form: `super(args)` as the first statement when the
  parent has a non-trivial `init`).

### Abstract methods

A base class may declare a method with no body:

```
// Actor.laz
abstract fn update(self)

pub fn tick(self) {
    self.update()    // dispatches to the subclass override
}
```

- A class containing an abstract method **cannot be instantiated**.
- Every concrete subclass **must** provide an `override fn update(self)`;
  otherwise it is a `SEMANTIC_ERROR`.

## Traits on a class

A class declares the traits it satisfies in an `impl` header and provides their
methods in the body:

```
impl Show, Drawable

pub fn show(self): str { ... }   // required by Show
pub fn draw(self) { ... }        // required by Drawable
```

The checker verifies every trait method is present with a matching signature.
Traits are **compile-time contracts only** — there is no `dyn`, and calls are
statically resolved. Trait declaration and semantics are in
[04-types-and-data.md](04-types-and-data.md).

## Calling across classes

```
import Counter

Counter.bump()           // static call, qualified
c = Counter()            // construct an instance (if init is pub)
v = c.value()            // instance method, implicit receiver
```

Inside its own file a class refers to its own members bare (`bump()`, `count`);
from another file everything is qualified through the imported class name.

## Lowering (summary)

A class becomes a Lua table acting as a metatable; instances are tables whose
metatable's `__index` is the class (and the class's metatable's `__index` is its
parent — that chain is how inheritance and `super` resolve). `init` becomes a
constructor function that `setmetatable`s a fresh table. Full details, including
how `static`, `override`, abstract stubs, and method dispatch are emitted, are in
[08-implementation.md](08-implementation.md).
