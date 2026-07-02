# Bindings

## Immutable locals

A bare `name = expr` declares an immutable local. It cannot be reassigned.

```lazarus
x = 10
label = "hello"
```

## Mutable locals

`mut name = expr` declares a mutable local that can be reassigned with `=` or a compound operator.

```lazarus
mut count = 0
count = count + 1
count += 1
```

## Typed locals

Any binding can carry an explicit type annotation `name: Type = expr`.

```lazarus
n: int = 42
name: str = "world"
mut total: float = 0.0
```

When a type is omitted, the compiler infers it from the initialiser. Explicitly annotating with `dynamic` opts out of type checking for that binding.

## Compound assignment

Mutable bindings (and mutable fields) support compound operators:

```lazarus
mut x = 0
x += 5    // x = x + 5
x -= 1    // x = x - 1
x *= 2    // x = x * 2
x /= 4    // x = x / 4
```

## Class fields vs locals

Bindings declared at the top level of a class file (outside any constructor or method) are **fields** when prefixed with a visibility keyword, or **static members** when also prefixed with `static`. Bare top-level bindings without a visibility keyword are local to the constructor.

See [Classes](classes.md) for details.
