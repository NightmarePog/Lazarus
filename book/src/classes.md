# Classes

## File = class

Every `.laz` file is a class. The filename (without the extension, in `PascalCase`) is the class name. There is no `class` keyword.

```
Counter.laz   →   class Counter
Vec2.laz      →   class Vec2
```

## Fields

Instance fields are declared at the top level of the file with a visibility keyword. They are private by default.

```lazarus
private count: int
private mut name: str
public score: float
```

- Fields without `mut` are immutable after construction.
- Fields are instance-level: each object has its own copy.

## Static members

`static` declares a member shared across all instances, or a static function.

```lazarus
private static base = 100
static max_size = 1000

static default_name(): str {
    return "unnamed"
}
```

Static members are accessed qualified by class name from outside the file: `Counter.max_size`.

## Constructor

A `constructor(params) { ... }` block initialises the object. It is called when the class is used as a function: `Counter(5)`.

```lazarus
private count: int

constructor(start: int) {
    .count = start
}
```

### `@auto` constructor

`@auto` before `constructor` automatically assigns each parameter to the same-named field, saving boilerplate:

```lazarus
private x: int
private y: int

@auto
constructor(x: int, y: int)
```

This is equivalent to:

```lazarus
constructor(x: int, y: int) {
    .x = x
    .y = y
}
```

### Field params (`.param`)

A constructor parameter prefixed with `.` both declares the field and assigns it:

```lazarus
constructor(.x: int, .y: int)
```

## Accessing `self`

Inside a method or constructor, instance fields and methods are accessed with a leading `.`:

```lazarus
get_count(): int {
    return .count
}

reset(): unit {
    .count = 0
}
```

There is no `self.` — the dot alone is the receiver.

## Visibility

- `private` — only accessible within the file.
- `public` — accessible from outside (via an instance or via the class name for static members).
- No keyword — defaults to private for class members; for local bindings, scoped to the block.

## Generic classes

A class can declare type parameters on its constructor:

```lazarus
private value: T

constructor<T>(v: T) {
    .value = v
}

get(): T {
    return .value
}
```

The type parameter `T` scopes to the entire file.

## Example

```lazarus
// Counter.laz
private mut count: int
private static step = 1

@auto
constructor(count: int)

public increment(): unit {
    .count = .count + Counter.step
}

public get(): int {
    return .count
}
```

Usage from another file:

```lazarus
import Counter

constructor() {
    c = Counter(0)
    c.increment()
    c.increment()
    // c.get() == 2
}
```
