# Methods

## Instance methods

An instance method is declared at the top level of a class file with a name, parameter list, and body. It receives the object via implicit `.` access.

```lazarus
greet(name: str): str {
    return "hello, " ++ name ++ " from " ++ .label
}
```

Methods can call other methods on `self` with a leading `.`:

```lazarus
describe(): str {
    return .greet("world") ++ "!"
}
```

## Static methods

`static` before the method name makes it a class-level function with no `self`:

```lazarus
static add(a: int, b: int): int {
    return a + b
}
```

Call with the class name: `Math.add(1, 2)`.

## Visibility

`public` exports a method; without it the method is private.

```lazarus
public get_value(): int {
    return .value
}

private helper(): str {
    return "internal"
}
```

## Return types

A method's return type follows its parameter list after a `:`:

```lazarus
count(): int {
    return .n
}

name(): str {
    return .label
}
```

Returning nothing uses `: unit`:

```lazarus
reset(): unit {
    .n = 0
}
```

## Expression-body shorthand

A single-expression body can be written with `=` instead of `{ return ... }`:

```lazarus
double(n: int): int = n * 2
label(): str = .name ++ " (" ++ .id ++ ")"
```

## Generic methods

A method can declare its own type parameters with `<T>` after the name:

```lazarus
wrap<T>(value: T): Option<T> {
    return Option.some(value)
}
```

## Function expressions

An anonymous function can be used as a value anywhere an expression is expected:

```lazarus
apply = fn(x: int): int { return x * 2 }
result = apply(5)
```

The type of a function expression is `(ParamTypes) -> ReturnType`:

```lazarus
transform: (int) -> int = fn(x: int): int { return x + 1 }
```

## Labeled arguments

Call sites can use labeled arguments for clarity. All arguments must be labeled if any are:

```lazarus
move(x: int, y: int): unit {
    .pos_x = x
    .pos_y = y
}

// called as:
obj.move(x: 10, y: 20)
```

## Local functions

A function can be declared inside a method body. It is a local binding scoped to that block:

```lazarus
compute(seed: int): int {
    bump(x: int): int {
        return x + 1
    }
    return bump(seed * 2)
}
```
