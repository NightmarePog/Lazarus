# Enums

An enum declares a closed set of named variants. Enums are declared inside a class file with the `enum` keyword.

## Declaration

```lazarus
enum Color {
    Red,
    Green,
    Blue
}
```

Variant names must be `PascalCase`. Variants are separated by commas (or newlines).

## Payload variants

A variant can carry data, declared as a parenthesised list of types:

```lazarus
enum Shape {
    Circle(float),
    Rect(float, float),
    Point
}
```

## Generic enums

Enums can be parameterised with type variables:

```lazarus
enum Result<T> {
    Ok(T),
    Err(str)
}
```

## Constructing variants

Nullary (no-payload) variants are accessed as `EnumName.VariantName`:

```lazarus
color = Color.Red
```

Payload variants are called like functions:

```lazarus
s = Shape.Circle(3.14)
r = Shape.Rect(10.0, 5.0)
```

## Matching enums

Use `match` to destructure enum values. Nullary variants match by name; payload variants bind their fields:

```lazarus
match shape {
    Circle(r) => {
        area = 3.14 * r * r
    }
    Rect(w, h) => {
        area = w * h
    }
    Point => {
        area = 0.0
    }
}
```

The binding names in `Variant(a, b)` are fresh variables scoped to the arm body.

## Enums inside a class

An enum declared in a file is scoped to that class. To use it from another file, import the containing class and prefix with the class name:

```lazarus
import Shapes

// ...
s = Shapes.Shape.Circle(1.0)
```

## Example: `Option`

The built-in `Option<T>` is a generic enum:

```lazarus
enum Option<T> {
    Some(T),
    None
}
```

Use it to represent optional values:

```lazarus
find(items: List<str>, target: str): Option<int> {
    mut i = 0
    for item in items {
        if item == target {
            return Option.some(i)
        }
        i += 1
    }
    return Option.none()
}
```
