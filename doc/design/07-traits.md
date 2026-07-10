# Traits

A trait defines a contract: a set of method signatures that a class can promise to implement. Traits are checked at compile time and cost nothing at runtime.

## Defining a trait

Traits can be defined in two places: in a dedicated `.trait.laz` file, or inline inside a class file with the `trait` keyword.

A `.trait.laz` file starts with an optional type parameter, then lists method signatures:

```
// Serializable.trait.laz
serialize(): str
deserialize(s: str): dynamic
```

With a type parameter:

```
// Container.trait.laz
<T>
get(i: int): Option<T>
len(): int
is_empty(): bool
```

The same trait defined inline:

```
// inside any .class.laz or .object.laz file
trait Serializable {
    serialize(): str
    deserialize(s: str): dynamic
}
```

## Implementing a trait

A class declares that it implements a trait with `implement TraitName`. The compiler then checks that the class provides every method the trait requires, with matching signatures.

```
// Config.class.laz
import std.Str
implement Serializable

private data: Map<str, str>

constructor() {
    .data = [:]
}

serialize(): str {
    mut out = ""
    for k, v in .data {
        out = out ++ k ++ "=" ++ v ++ "\n"
    }
    return out
}

deserialize(s: str): dynamic {
    // simplified: returns a new Config from a serialized string
    mut cfg = Config()
    for line in Str.split(s, "\n") {
        mut parts = Str.split(line, "=")
        match parts.get(0) {
            Some(k) => {
                match parts.get(1) {
                    Some(v) => { cfg.data[k] = v }
                    None    => { }
                }
            }
            None => { }
        }
    }
    return cfg
}
```

If the class is missing any required method, or if a method's signature does not match, the compiler reports an error.

## Trait method signatures

A trait method signature names the method, its parameters, and the return type. No body. Parameters are typed the same way as regular method parameters:

```
trait Drawable {
    draw(canvas: Canvas): unit
    bounds(): Rect
    visible(): bool
}
```

Property requirements (requiring a field of a given type) are also supported:

```
trait Named {
    name: str
}
```

## A practical example

Here is a small example using a trait to define a common interface for different logging backends:

```
// Logger.trait.laz
log(level: str, msg: str): unit
flush(): unit
```

```
// ConsoleLogger.class.laz
import std.Sys
implement Logger

log(level: str, msg: str): unit {
    Sys.print(f"[{level}] {msg}")
}

flush(): unit { }

constructor() { }
```

```
// FileLogger.class.laz
import std.File
implement Logger

private handle: dynamic

constructor(path: str) {
    .handle = File.open(path, "w")
}

log(level: str, msg: str): unit {
    .handle.write(f"[{level}] {msg}\n")
}

flush(): unit {
    .handle.close()
}
```

Both `ConsoleLogger` and `FileLogger` satisfy the `Logger` trait. The compiler checks this at build time, so you never get a runtime failure from a missing method.
