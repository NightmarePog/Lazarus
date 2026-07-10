# Lua Interop

Lazarus compiles to Lua and can call any Lua function or global. Two mechanisms handle this: typed `extern` declarations for safe, checked calls, and inline `lua` bodies for everything else.

## extern declarations

An `extern` declaration binds a Lazarus name to a Lua global and gives it a type signature. After the declaration, calls through that name are type-checked and emit directly to the Lua global:

```
// In a .object.laz file
extern print(s: str): unit = "print"
extern read_line(): Option<str> = "io.read"
extern exit(code: int): unit = "os.exit"
```

The string on the right is the Lua expression to emit. It can be a global function name, a dotted member, or anything Lua evaluates as a callable:

```
extern floor(x: float): Option<int>  = "math.floor"
extern upper(s: str): Option<str>    = "string.upper"
extern format(fmt) = "string.format"
```

`extern` declarations without a return type, or with an `Option<T>` return type, wrap the Lua return value at the boundary. If Lua returns `nil`, the Lazarus side receives `None`.

You can leave a parameter untyped when the underlying Lua function is variadic or accepts multiple numeric types:

```
extern max(a, b) = "math.max"    // accepts int or float
```

Externs are declarations only: no Lua code is emitted for the declaration itself. Calls to the name emit the Lua global call directly.

## lua bodies

For cases that cannot be expressed as a simple `extern` binding, write the Lua implementation inline with a `lua` body:

```
private lua read_bytes(n: int): Option<str> {
    local s = io.read(n)
    if s == nil then return 'None' end
    return { kind = 'Some', _1 = s }
}
```

A `lua` body is raw Lua code. It has access to the method's parameters by name, and inside a class method it has `self` as the instance. The return type annotation tells the type checker what to expect, but the Lua code is not checked.

The typical pattern is to write a private `lua` helper that wraps a Lua API, then expose it through a typed `extern` that routes to the helper:

```
private lua __lz_str_find(s, sub): int {
    return (string.find(s, sub, 1, true))
}

extern find(s: str, sub: str): Option<int> = "Str.__lz_str_find"
```

`lua` bodies can appear on instance methods, static methods, and private helpers. Add `static` or `private` in front of `lua` the same way you would for a regular method:

```
public lua push(v: T): unit {
    self.items[#self.items + 1] = v
}

private static lua from_raw(raw): List<dynamic> {
    local self = {}
    self.items = raw
    return self
}
```

## Platform gating

Some Lua environments expose different globals. The `platform` modifier restricts a declaration to a specific runtime:

```
platform(cc)     extern sleep(n: float): unit = "os.sleep"
platform(lua54)  extern sleep(n: float): unit = "os.sleep"
platform(roblox) extern sleep(n: float): unit = "task.wait"
```

Pass the platform name at build time with `--platform`:

```sh
lua bin/lazarusc.lua Main.class.laz --platform cc
```

The compiler emits only the declarations that match the given platform. Declarations without a `platform` modifier are always included.

## A practical example

Here is a small terminal utility object that wraps some ANSI escape codes:

```
// Terminal.object.laz
import std.Str

private lua __lz_move(row, col): unit {
    io.write("\27[" .. row .. ";" .. col .. "H")
}

private lua __lz_clear_screen(): unit {
    io.write("\27[2J\27[H")
}

extern write(s: str): unit = "io.write"

clear(): unit {
    Terminal.__lz_clear_screen()
}

move_to(row: int, col: int): unit {
    Terminal.__lz_move(row, col)
}

center(s: str, width: int): str {
    mut n   = Str.len(s).unwrap_or(0)
    mut pad = (width - n) / 2
    return Str.rep(" ", pad).unwrap_or("") ++ s
}
```

Usage:

```
import Terminal
import std.Sys

static main() {
    Terminal.clear()
    Terminal.move_to(5, 10)
    Terminal.write(Terminal.center("hello", 80))
}
```

The Lua calls are type-checked through the `extern` boundary and the type annotations on `lua` bodies. The Lua code itself is not checked: that is the tradeoff at the interop boundary. A wrong signature in an `extern` is a runtime bug, not a compile error.
