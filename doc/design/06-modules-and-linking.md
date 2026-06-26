# 06 — Modules, Imports, Libraries & Linking

Lazarus has no runtime module system. Every program is **bundled at compile time
into one self-contained Lua file** with no `require` — ideal for dropping onto a
ComputerCraft / OpenComputers computer.

## Importing

A file must `import` another class before using it. Imports sit at the top of the
file and make the dependency explicit:

```
import Vec2                       // a class at the project root
import actors.enemy.Enemy         // a class in actors/enemy/Enemy.laz
```

- `import seg.seg.Class` is a **dot-separated path resolved from the project root**
  (the entry file's directory). The final segment is the class name and the file
  stem; the leading segments are folders. `import std.Str` -> `<root>/std/Str.laz`.
- Every import is project-root-relative regardless of which file it sits in —
  there is **no `../` form and no quoted-path form**.
- Imported classes are used **qualified by the class name** (the final segment):
  `Vec2(1, 2)`, `Vec2.zero()`, `Enemy.spawn()`. There is no selective/unqualified
  import and no aliasing in v1.

## Exporting

There is no separate `export` statement — **`pub` is the export marker.** An
item (`fn`, field, `enum`, `trait`, `init`) is visible to importers only if it is
`pub`; everything else is private to its class.

```
// Vec2.laz
pub x: int = 0          // exported field
pub init(x: int) { ... } // exported constructor (others can construct Vec2)
pub fn add(self, o: Vec2): Vec2 { ... }
fn normalize(self) { ... }   // private helper, not visible to importers
```

A class with a private `init` cannot be constructed from other files (useful for
singletons / factory-only types).

## Writing a library

A **library** is simply a set of `.laz` files with `pub` items and **no
`fn main()`**. It is consumed by another project that imports its classes by
their dotted, root-relative path. Because v1 has **no manifest**, a library is
distributed as source and **vendored under the consumer's project root** (the
same way `std/` is just a folder at the root):

```
mygame/
  Main.laz            // import vec.Vec
  vec/
    Vec.laz           // pub items, no main()
```

The bundler pulls the referenced library files into the consumer's single output.
(A `lazarus.toml` manifest with named dependencies is designed but **deferred** —
see the sketch at the end.)

## Entry point

The file you build is the **program entry**. It must define a static
`fn main()` (a `self`-less function). The bundler:

1. emits every class/enum/function definition reachable through imports,
2. then appends a call to the entry class's `main()`.

```
// Main.laz
import World

fn main() {
    w = World()
    w.run()
}
```

Top-level **field defaults and `static` initializers** run in source order as the
emitted code loads, *before* `main()` is called.

## Linking / bundling

```
lazarus build src/Main.laz                 # -> src/Main.lua (or -o <path>)
lazarus build src/Main.laz -o out/prog.lua
lazarus build src/Main.laz -o -            # to stdout
```

- The compiler starts at the entry file, follows `import`s, and compiles each
  class to Lua.
- **v1 links every imported file whole** (no tree-shaking): if you import a class,
  all of its code is emitted, used or not. This is simpler and predictable;
  **tree-shaking** (emitting only code reachable from `main()`) is a planned
  optimization that will shrink outputs later.
- All classes share one Lua chunk; name collisions are avoided by qualifying
  emitted names per class (e.g. `Vec2_add`); see
  [08-implementation.md](08-implementation.md).

## Resolution & errors

- A class name must equal its filename (`PascalCase`). Mismatch → error.
- An `import` that cannot be resolved → `SEMANTIC_ERROR` with the path.
- Using a non-`pub` item from another class → `SEMANTIC_ERROR`.
- A cyclic `import` is allowed for *type references* (classes can refer to each
  other) but a cycle in **top-level initialization order** is reported.

## Deferred: the `lazarus.toml` manifest

Planned for when multi-project dependencies are needed (not in v1). Sketch:

```toml
[package]
name    = "turtle-miner"
version = "0.1.0"
kind    = "program"        # "program" (has main) | "library"

[build]
entry  = "src/Main.laz"
target = "lua50"           # lua50 | lua54
out    = "build/prog.lua"

[dependencies]
vec = { path = "../vec" }  # later: registry versions
```

This would let `lazarus build` run with no flags, give projects identity/version,
and resolve named library dependencies instead of relative paths.
