# Objects and Modules

## Object files

A `.object.laz` file defines a static namespace. Unlike a class, it cannot be instantiated. Every member is implicitly static. Object files are used for utility functions, math helpers, and Lua API wrappers.

```
// MathUtils.object.laz

clamp(v: int, lo: int, hi: int): int {
    if v < lo { return lo }
    if v > hi { return hi }
    return v
}

lerp(a: float, b: float, t: float): float {
    return a + (b - a) * t
}
```

Call members through the module name: `MathUtils.clamp(x, 0, 100)`.

There is no `constructor`, no instance fields, and no `self`. Everything in an object file is a function or a static value.

## Imports

A file declares its dependencies with `import`. Paths are dot-separated and resolved from the project root (the directory you pass to the compiler):

```
import std.Sys
import std.Str
import std.Option
import geometry.Vec2
import geometry.shapes.Circle
```

The last segment of the path is the class or module name. After importing `geometry.Vec2`, you use it as `Vec2(1, 2)`, `Vec2.zero()`, etc.

Every import is project-root-relative. There is no relative `../` form.

## Building a multi-file project

The compiler takes a single entry file and follows its imports transitively. Everything reachable ends up in one output file:

```
lua bin/lazarusc.lua src/Main.class.laz
lua Main.lua
```

A typical project looks like this:

```
myproject/
  Main.class.laz
  engine/
    World.class.laz
    Entity.class.laz
  util/
    Grid.object.laz
  std/         (symlinked or copied from the Lazarus stdlib)
```

`Main.class.laz` imports from `engine.World`, which imports from `engine.Entity`, and so on. The compiler resolves all of that, checks types, and emits one `Main.lua`.

## The standard library

The standard library lives in `std/` and is imported with the `std.` prefix:

```
import std.Sys     // IO and process utilities
import std.Str     // String operations
import std.Num     // Math functions
import std.Path    // File path manipulation
import std.List    // List type and methods
import std.Map     // Map type and methods
import std.Option  // Option<T> enum and helpers
import std.Result  // Result<T> enum and helpers
import std.File    // File handle
import std.Json    // JSON parsing and emission
import std.Time    // Clock and time
import std.Task    // Async task utilities
```

Most programs import at least `std.Sys` for printing and `std.Str` for string operations.

## Externs in object files

The standard library objects are implemented with `extern` declarations, which bind a Lazarus name to an existing Lua global:

```
// std/Sys.object.laz
extern print(s): unit = "print"
extern read_line(): Option<str> = "io.read"
extern exit(code: int): unit = "os.exit"
```

After `import std.Sys`, you call these as `Sys.print("hello")`. The type annotation on the `extern` declaration is what the type checker validates against. The emitted Lua just calls the Lua global directly.

See [07-interop.md](07-interop.md) for the full interop system.

## Library compilation

If you are building a reusable module rather than a runnable program, compile with `--lib`:

```sh
lua bin/lazarusc.lua MyLib.class.laz --lib
```

Library mode skips the entry-point call and prepends a `LAZARUS_META` header to the output. The linker can then load this prebuilt `.lua` without re-compiling the source.
