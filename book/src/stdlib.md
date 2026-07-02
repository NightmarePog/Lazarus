# Standard Library

The standard library lives in the `std/` directory and is imported like any other class. Each module is a collection of `extern` bindings to Lua's built-in functions.

## `std.Str`

String operations wrapping Lua's `string` library.

```lazarus
import std.Str
```

| Function | Signature | Description |
|----------|-----------|-------------|
| `upper` | `(s: str): Option<str>` | Uppercase |
| `lower` | `(s: str): Option<str>` | Lowercase |
| `len` | `(s: str): Option<int>` | String length |
| `sub` | `(s: str, i: int, j: int): Option<str>` | Substring (`i`/`j` are 1-based) |
| `byte` | `(s: str, i: int): Option<int>` | Byte value at index |
| `char` | `(n: int): Option<str>` | Character from byte value |
| `rep` | `(s: str, n: int): Option<str>` | Repeat string `n` times |
| `format` | `(fmt: str): Option<str>` | `string.format`-style formatting |
| `find` | `(s: str, sub: str): Option<int>` | 1-based index of `sub`, or `None` |

All functions return `Option` — call `.unwrap()` or `.unwrap_or(default)` on the result.

```lazarus
import std.Str

upper = Str.upper("hello").unwrap()   // "HELLO"
length = Str.len("hi").unwrap()       // 2
first = Str.sub("abc", 1, 1).unwrap() // "a"
```

## `std.Sys`

I/O and process control wrapping Lua's runtime functions.

```lazarus
import std.Sys
```

| Function | Signature | Description |
|----------|-----------|-------------|
| `print` | `(s: dynamic): unit` | Print followed by newline (`print`) |
| `write` | `(s: dynamic): unit` | Print without newline (`io.write`) |
| `read_line` | `(): Option<str>` | Read one line from stdin |
| `read_all` | `(fmt: dynamic): Option<str>` | Read all stdin |
| `argv` | `(i: int): Option<str>` | Command-line argument at index `i` |
| `read_file` | `(path: str): Option<str>` | Read entire file contents |
| `time` | `(): Option<int>` | Current Unix timestamp |
| `clock` | `(): Option<float>` | CPU clock in seconds |
| `exit` | `(code: int): unit` | Exit the process |
| `open` | `(s: str, mode: str): Option<dynamic>` | Open a file handle |
| `panic` | `(message: str): unit` | Abort with a Lua `error` |

```lazarus
import std.Sys

Sys.print("hello")
line = Sys.read_line().unwrap_or("")
Sys.exit(0)
```

## `std.Num`

Numeric utilities wrapping Lua's `math` library.

```lazarus
import std.Num
```

| Function | Signature | Description |
|----------|-----------|-------------|
| `floor` | `(x: float): Option<int>` | Round down |
| `ceil` | `(x: float): Option<int>` | Round up |
| `abs` | `(x: dynamic): Option<dynamic>` | Absolute value |
| `max` | `(a: dynamic, b: dynamic): Option<dynamic>` | Maximum of two values |
| `min` | `(a: dynamic, b: dynamic): Option<dynamic>` | Minimum of two values |
| `to_number` | `(s: str): Option<float>` | Parse a string as a number, or `None` |
| `to_text` | `(n: dynamic): Option<str>` | Convert a number to its string representation |
| `to_int` | `(x: float): Option<int>` | Floor to int |
| `to_float` | `(x: dynamic): Option<float>` | Convert to float |

```lazarus
import std.Num

floored = Num.floor(3.7).unwrap()   // 3
text = Num.to_text(42).unwrap()     // "42"
parsed = Num.to_number("3.14").unwrap_or(0.0)
```
