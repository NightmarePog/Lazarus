# Types

The Lazarus type system is static and erased: all type information is checked at compile time and removed from the Lua output.

## Primitive types

| Type | Description | Example literal |
|------|-------------|-----------------|
| `int` | Integer number | `42` |
| `float` | Floating-point number | `3.14` |
| `str` | String | `"hello"` |
| `bool` | Boolean | `true`, `false` |

`int` and `float` are distinct types. There is no automatic coercion between them.

## `dynamic`

`dynamic` opts out of type checking. A `dynamic` value can be used anywhere without a type error. This is the default for unannotated parameters and the return type of `extern` declarations.

```lazarus
process(x: dynamic): dynamic {
    return x
}
```

## `unit`

`unit` is the return type of a method or function that returns nothing (analogous to `void`). It is written as `: unit` on the return type.

```lazarus
log(msg: str): unit {
    Sys.print(msg)
}
```

## `Option<T>`

`Option` is a built-in generic type representing an optional value.

- `Option.some(value)` — wraps a value
- `Option.none()` — the absent case

Common methods on `Option`:

```lazarus
mut v: Option<int> = Option.some(10)
v.unwrap()          // returns the value or panics
v.unwrap_or(0)      // returns the value or a default
v.is_some()         // bool
v.is_none()         // bool
```

## Generic types

Class and enum names can be parameterised with `<T>`:

```lazarus
// Using a generic class
mut items: List<str> = []
mut table: Map<str, int> = [:]
```

`List<T>` and `Map<K, V>` are built-in collection types. See [Classes](classes.md) for how to declare generic classes.

## Union types

A union type `A | B` accepts either type. Union types are erased at codegen.

```lazarus
display(value: int | str): unit {
    Sys.print(value)
}
```

## Function types

A function type `(P1, P2) -> R` describes a callable value.

```lazarus
apply(f: (int) -> int, x: int): int {
    return f(x)
}
```

## Type annotations syntax

Type annotations appear after a `:` on bindings, parameters, fields, and return positions:

```lazarus
name: str = "Lazarus"

greet(who: str): str {
    return "hello " ++ who
}
```
