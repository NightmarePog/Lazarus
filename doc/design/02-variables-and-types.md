# Variables and Types

## Bindings

A name assignment is immutable by default. Once bound, the name cannot be reassigned:

```
x = 10
x = 20  // error: x is not mutable
```

Add `mut` to make it reassignable:

```
mut x = 10
x = 20  // fine
x += 5  // also fine: compound assignment desugars to x = x + 5
```

Compound assignment works for all four arithmetic operators: `+=`, `-=`, `*=`, `/=`.

Immutability is the default because most local values in practice never change. When you do want mutation, `mut` makes it explicit and visible.

## Type annotations

Type annotations are optional on local variables. The compiler infers the type from the right-hand side:

```
x = 42          // int, inferred
name = "hello"  // str, inferred
flag = true     // bool, inferred
```

You can write the type explicitly if you want:

```
x: int = 42
name: str = "hello"
```

On method parameters and return types, annotations are the convention and are required for type checking to work. Without them, the parameter or return type is `dynamic`, which disables checking for that part of the signature:

```
static add(a: int, b: int): int {
    return a + b
}
```

## Primitive types

Lazarus has four primitive types:

`int` is a whole number. `float` is a real number. They are distinct and do not mix: adding an `int` and a `float` without an explicit conversion is a type error. This distinction matters because a future backend will map them to Lua 5.4's real integer and float types.

```
n: int   = 42
x: float = 3.14
```

`str` is a string. `bool` is a boolean, with the literals `true` and `false`.

There is no `nil` in Lazarus. Absence is represented with `Option<T>` (see [05-types-and-data.md](05-types-and-data.md)).

## The dynamic type

`dynamic` is the escape hatch. A value of type `dynamic` bypasses type checking. It flows into any typed slot and accepts any operation. Most code should avoid it, but it is useful at the Lua boundary (see [07-interop.md](07-interop.md)) and in generic containers that the type system cannot represent yet.

```
x: dynamic = anything_goes()
```

## unit

`unit` is the return type for functions that return nothing. It is equivalent to `void` in other languages. You write it explicitly in method signatures:

```
log(msg: str): unit {
    Sys.print(msg)
}
```

## Function types

Functions are first-class values. The type of a function that takes an `int` and returns a `str` is written `(int) -> str`:

```
static apply(n: int, f: (int) -> int): int {
    return f(n)
}
```

Multiple parameters are separated by commas: `(str, int) -> bool`. A function that takes nothing uses empty parentheses: `() -> str`.

Anonymous functions use the `fn` keyword:

```
double = fn(x: int): int = x * 2
greet  = fn(name: str): str { return "hello " ++ name }
```

The short form `fn(params): RetType = expr` works for single-expression bodies. The block form `fn(params): RetType { ... }` works for anything else.

## Strings

Regular strings use double quotes with no interpolation:

```
greeting = "hello, world"
path = "src/main.laz"
```

Supported escape sequences: `\n`, `\t`, `\r`, `\"`, `\\`.

Format strings use the `f` prefix. Expressions inside `{}` are evaluated and embedded:

```
name = "al"
n    = 42
msg  = f"hello {name}, count is {n + 1}"
```

Multi-line strings use triple quotes. The `f` prefix works here too:

```
block = """
    line one
    line two
    """

generated = f"""
    name: {name}
    count: {n}
    """
```

String concatenation uses `++`, not `+`. The `+` operator is numeric only:

```
full = first ++ " " ++ last
```

## Summary

- `mut` opts into reassignment; bindings are immutable by default.
- Type annotations on locals are optional; on method signatures they enable type checking.
- Primitive types: `int`, `float`, `str`, `bool`, `unit`, `dynamic`.
- `f"..."` for interpolated strings, `"..."` for plain strings, `"""..."""` for multi-line.
- `++` for string concatenation.
- Function types are written `(T) -> U`; anonymous functions use `fn`.
