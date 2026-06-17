# 01 — Overview

## What Lazarus is

Lazarus is a small, statically-typed, **class-oriented** language that compiles
to a single self-contained **Lua** file. It exists to give large Lua programs —
especially ComputerCraft / OpenComputers mods — real structure: classes with
constructors and inheritance, a static type system that catches mistakes before
they reach the device, and a clean module system, all with **minimum
boilerplate**.

The guiding principle: **the file is the class.** There is no `class` wrapper to
write — opening a `.laz` file *is* opening a class body. The filename is the
class name.

## The "file = class" model

```
// Counter.laz   ->   class Counter
count: int = 0                  // an instance field (private, immutable)

init() { }                      // constructor; Counter() makes one

pub fn value(self): int {       // an instance method
    return self.count
}
```

A class is a **reference type**: you construct instances with `Counter()`, each
carries its own field values, methods take `self`, and classes can inherit from
one another. This is ordinary object orientation — it just happens that one file
holds exactly one class, so the class needs no surrounding braces or name
declaration.

Two kinds of user-defined type exist:

- **Classes** (the file itself) — identity, constructor (`init`), inheritance
  (`extends`), instance + `static` members, methods with `self`. A class with
  only fields is your equivalent of a plain data record.
- **Enums** (declared *inside* a class file) — sum types with optional payloads,
  consumed by `match`. Enums are **data-only**.

There is deliberately **no `struct`**, and **no user generics** in v1. The
generic-looking built-ins — `Option<T>`, `Result<T, E>`, `[T]`, `{K: V}` — are
provided by the compiler.

## A complete example

```
// Vec2.laz  ->  class Vec2  (used as a data record)
pub x: int = 0
pub y: int = 0

init(x: int, y: int) {
    self.x = x
    self.y = y
}

pub fn add(self, o: Vec2): Vec2 {
    return Vec2(self.x + o.x, self.y + o.y)
}
```

```
// Main.laz  ->  class Main  (the program)
import Vec2

enum Status { Ok, Blocked }

fn main() {                       // no self -> static; the entry point
    a = Vec2(1, 2)
    b = Vec2(3, 4)
    c = a.add(b)                  // implicit receiver

    msg = "sum = ({c.x}, {c.y})"  // string interpolation

    if c.x > 0 and c.y > 0 {
        report(Status.Ok, msg)
    } else {
        report(Status.Blocked, msg)
    }
}

fn report(s: Status, msg: str) {
    match s {
        Ok => { print_line(msg) },
        Blocked => { print_line("blocked") },
    }
}
```

This whole program (both files) compiles to **one** Lua file with `Main.main()`
called at the bottom. Nothing is required at runtime.

## Pipeline

Lazarus keeps its five-stage pipeline (see [`../pipeline.md`](../pipeline.md)):

```
source ─▶ Lexer ─▶ Parser ─▶ Schematic ─▶ Optimizer ─▶ Codegen ─▶ Lua
                                 (types)                 (bundle)
```

The type system is the heavy new addition and lives in **Schematic** (today it
only does scope/name checks). Types are **erased**: by the time Codegen runs, the
AST is plain class/enum/expression structure and the emitted Lua carries no type
information — so the static guarantees cost nothing at runtime.

## Target runtime

v1 targets **Lua 5.0**. That backend has three quirks the compiler works around,
none of which affect the surface language:

- no `#` length operator → `.len()` lowers to `table.getn` / a tracked length;
- no `%` modulo → synthesized as `a - floor(a / b) * b`;
- varargs via the `arg` table rather than `...`.

A **Lua 5.4** backend is planned. That is the reason `int` and `float` are
distinct types now even though 5.0 represents both as doubles: under 5.4 they map
to genuine integer/float, and code written today stays correct.

See [08-implementation.md](08-implementation.md) for the full lowering.
