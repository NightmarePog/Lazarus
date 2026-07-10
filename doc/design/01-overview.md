# Overview

Lazarus is a small, statically-typed language that compiles to a single Lua file. You get real classes, a type system that catches mistakes before runtime, and a module system that resolves imports at compile time. The output is plain Lua that runs anywhere Lua 5.1 runs, with no runtime dependencies.

The language was designed for environments where you have Lua but not much else: ComputerCraft computers, embedded scripting runtimes, game mod environments, or any place where dropping a single `.lua` file is simpler than managing a package ecosystem.

## Three kinds of files

Every Lazarus source file ends in `.laz`, but the suffix before that tells the compiler what kind of thing it defines:

**`.class.laz`** defines a class. Classes are instantiable types: they have a constructor, instance fields, and instance methods. The file name (without the suffix) becomes the class name, so `Counter.class.laz` defines a class called `Counter`.

**`.object.laz`** defines an object. Objects are static namespaces with no instances. Every member is implicitly static. They are used for utility modules, math helpers, and Lua API wrappers. `Str.object.laz` defines `Str`, which you call as `Str.upper(s)`.

**`.trait.laz`** defines a trait. Traits are contracts: a set of method signatures that a class can promise to implement. The standard library trait `Iterable.trait.laz` defines what it means to be iterable.

All filenames are PascalCase.

## A first example

Here is a small program that creates a counter, increments it, and prints the result:

```
// Counter.class.laz
import std.Sys

private count: int = 0

constructor() { }

increment() {
    .count = .count + 1
}

value(): int {
    return .count
}

static main() {
    mut c = Counter()
    c.increment()
    c.increment()
    c.increment()
    Sys.print(f"count is {c.value()}")
}
```

Run it:

```sh
lua bin/lazarusc.lua Counter.class.laz
lua Counter.lua
# count is 3
```

A few things to notice:

The file name is the class name. There is no `class Counter` declaration anywhere.

Fields are accessed inside methods with a leading dot: `.count`. This is shorthand for `self.count`. The `self` keyword also exists and can be used directly, but the dot form is more common.

`static main()` is the entry point. The compiler appends a call to it at the end of the output. Static methods belong to the class, not to any instance.

`f"..."` is a format string. Expressions inside `{}` are evaluated and interpolated into the string. Regular `"..."` strings have no interpolation.

## Building

The self-hosted compiler is `bin/lazarusc.lua`. It takes a source file and writes `<ClassName>.lua` to the current directory:

```sh
lua bin/lazarusc.lua MyProgram.class.laz
lua MyProgram.lua
```

**The stdlib is not bundled.** The compiler looks for `std/` next to your source file. Before compiling your own projects, either copy or symlink `std/` from the Lazarus repo into your project directory, or pass `--pkg-path` to tell the compiler where to find it:

```sh
# symlink (recommended -- stays up to date)
ln -s /path/to/lazarus/std ./std

# or pass it at compile time
lua bin/lazarusc.lua MyProgram.class.laz --pkg-path /path/to/lazarus
```

Flags:

```sh
--check          # report errors without writing output
--lib            # compile as a library (no entry-point call)
--platform <n>   # set the target platform name
-O0 / -O1 / -O2 / -Os  # optimization level (O0 is default)
```

Via make:

```sh
make selfbuild FILE=MyProgram.class.laz
```

## How compilation works

The compiler resolves all imports, runs each file through the pipeline (lexer, parser, schematic, typechecker, optimizer, codegen), and bundles everything into one chunk. The output has no `require` calls and no runtime dependencies. Dependencies are emitted in the correct order so a class is always defined before it is used.

The type system is erased at codegen. The emitted Lua carries no type information and pays no runtime cost for it.

Continue to [02-variables-and-types.md](02-variables-and-types.md) for the basics of variables and the type system.
