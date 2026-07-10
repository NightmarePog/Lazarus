# Classes

A `.class.laz` file defines a class. The file name (without the suffix) is the class name. There is no `class` keyword: the top level of the file is the class body.

## Fields

Instance fields are declared at the top level of the file with a visibility keyword and a name. The type annotation is optional but recommended:

```
// Point.class.laz
public x: int
public y: int
private label: str = "point"
```

`public` makes a field accessible to other files. `private` keeps it internal. Fields have no default visibility: one of the two must be written. A field with a default value (`= expr`) uses that value if the constructor does not set it. A field without a default must be assigned in the constructor.

Static fields belong to the class itself rather than any instance:

```
private static count: int = 0
public static max: int = 1000
```

## Constructor

A class has one `constructor` block. Instances are created by calling the class name:

```
constructor(x: int, y: int) {
    .x = x
    .y = y
}

p = Point(3, 4)
```

Inside the constructor, `.field` assigns an instance field. This is shorthand for `self.field`.

For fields that are simply assigned from a constructor parameter with the same name, there is a shorthand: prefix the parameter name with a dot. This declares the field and assigns it in one step:

```
constructor(.x: int, .y: int) { }
```

This is exactly equivalent to declaring the fields at the top and writing `.x = x`, `.y = y` in the body. If the field was already declared above with an explicit visibility, the shorthand just generates the assignment without re-declaring it.

## Instance methods

Instance methods are declared with just a name, parameters, and a body. No keyword is needed:

```
distance(other: Point): float {
    mut dx = .x - other.x
    mut dy = .y - other.y
    return Num.sqrt((dx * dx + dy * dy) as float)
}

label(): str {
    return .label
}
```

Inside an instance method, `.field` reads or writes an instance field. The `self` keyword also works and is useful when you need to pass the current instance as an argument or call into a `lua` body.

Methods are public by default. Add `private` to restrict access to the class itself:

```
private validate(): bool {
    return .x >= 0 and .y >= 0
}
```

## Static methods

Static methods belong to the class, not to any instance. They are declared with `static`:

```
static origin(): Point {
    return Point(0, 0)
}
```

Static methods are called through the class name: `Point.origin()`. They cannot access instance fields.

The entry point of a program is `static main()` in the file you build.

## Nested functions

Functions can be defined inside other functions. They close over the outer scope and can call each other:

```
static sum_of_squares(items: List<int>): int {
    square(n: int): int {
        return n * n
    }
    mut total = 0
    for x in items {
        total = total + square(x)
    }
    return total
}
```

## A complete example

```
// Counter.class.laz
import std.Sys

private count: int = 0
private step: int

constructor(step: int) {
    .step = step
}

tick() {
    .count = .count + .step
}

value(): int {
    return .count
}

reset() {
    .count = 0
}

static make(step: int): Counter {
    return Counter(step)
}

static main() {
    mut c = Counter.make(5)
    c.tick()
    c.tick()
    c.tick()
    Sys.print(f"value: {c.value()}")        // value: 15
    c.reset()
    Sys.print(f"after reset: {c.value()}")  // after reset: 0
}
```

## Enums

Enums are declared inside a class file. They are sum types: a value of an enum type is exactly one of its variants, and each variant can carry data:

```
enum Direction {
    North,
    South,
    East,
    West
}

enum Shape {
    Circle(float),
    Rect(float, float),
    Dot
}
```

Variants without payload are bare names. Variants with payload list the types in parentheses.

Use `match` to branch on an enum value (see [04-control-flow.md](04-control-flow.md)):

```
static describe(d: Direction): str {
    match d {
        North => { return "north" }
        South => { return "south" }
        East  => { return "east" }
        West  => { return "west" }
    }
}
```

## Inline traits

Traits can also be declared inside a class file. A class implements a trait by declaring `implement TraitName` at the top level and providing the required methods:

```
trait Renderable {
    draw(): str
    bounds(): Rect
}

implement Renderable

draw(): str {
    return f"point at ({.x}, {.y})"
}

bounds(): Rect {
    return Rect(.x, .y, 1, 1)
}
```

See [06-traits.md](06-traits.md) for the full trait system.
