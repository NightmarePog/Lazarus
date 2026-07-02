# Interfaces

An interface defines a structural contract: a set of methods and properties a class must provide. Interfaces are erased at codegen — they exist only at compile time.

## Declaring an interface

```lazarus
interface Drawable {
    draw(): unit
    width: int
    height: int
}
```

- Method signatures have no body.
- Property requirements list the name and type.
- Separated by semicolons or newlines.

## Generic interfaces

```lazarus
interface Container<T> {
    get(): Option<T>
    size(): int
}
```

## `#interface` files

A file beginning with `#interface` is itself an interface declaration. The interface name is taken from the filename.

```lazarus
// Printable.laz
#interface

to_string(): str
```

This declares an interface named `Printable` with one method requirement.

## Implementing an interface

A class satisfies an interface structurally — no explicit `impl` declaration is required. If the class provides all required methods and properties with matching types, it conforms.

```lazarus
// Box.laz
public width: int
public height: int

@auto
constructor(width: int, height: int)

public draw(): unit {
    Sys.print("box " ++ width ++ "x" ++ height)
}
```

`Box` satisfies `Drawable` automatically because it has `draw()`, `width`, and `height`.

## Using interface types

An interface type can be used anywhere a type is expected. The compiler checks that the passed value conforms at the call site.

```lazarus
render(d: Drawable): unit {
    d.draw()
}
```

## Inline interface declarations

An interface can also be declared inline inside a class file:

```lazarus
interface Serializable {
    to_json(): str
}
```
