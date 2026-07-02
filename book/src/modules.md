# Modules

## `import`

`import` brings another class into scope. The path is a dotted sequence of directory names followed by the class name (filename without `.laz`), resolved from the project root.

```lazarus
import Counter
import std.Str
import actors.enemy.Enemy
```

After import, the class is referred to by its unqualified name:

```lazarus
import std.Str

len = Str.len("hello")
```

Imports are hoisted — they can appear anywhere in the file but are always processed before the rest of the program.

## `extern`

`extern` declares a Lua function as a Lazarus-callable binding. It allows calling into the Lua standard library or other Lua code.

```lazarus
extern print(s: str): unit = "print"
extern floor(x: float): float = "math.floor"
```

The string after `=` is the Lua function name (or dotted path). The result is wrapped in `Option` at the boundary — if the Lua function returns `nil`, the result is `Option.none()`.

### Typed `extern`

Parameters and return types can be annotated:

```lazarus
extern len(s: str): int = "string.len"
```

### `@platform`

`@platform(name)` annotates an extern with the target platform, for platform-specific bindings:

```lazarus
@platform(roblox)
extern wait(t: float): unit = "task.wait"
```

## `#object`

A file beginning with `#object` is a static module: every member is implicitly static. There is no constructor and no instances.

```lazarus
// MathUtils.laz
#object

public clamp(x: int, lo: int, hi: int): int {
    if x < lo { return lo }
    if x > hi { return hi }
    return x
}

private limit = 1000
```

Used from another file:

```lazarus
import MathUtils

n = MathUtils.clamp(200, 0, 100)
```

`static` and `constructor` are errors inside an `#object` file.

## Linking

`lazarusc` bundles all imported files into the output `Main.lua` at compile time. There is no runtime `require`. Every file used by the program is inlined.
