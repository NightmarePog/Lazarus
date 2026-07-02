# Strings

## Basic string literals

Strings are delimited by double quotes:

```lazarus
greeting = "hello, world"
path = "std/Str"
```

Supported escape sequences:

| Escape | Meaning |
|--------|---------|
| `\n` | Newline |
| `\t` | Tab |
| `\"` | Double quote |
| `\\` | Backslash |

## String concatenation

Use `++` to concatenate strings. `+` is reserved for arithmetic.

```lazarus
full_name = first ++ " " ++ last
```

Non-string values can be concatenated by converting them first (see [`Num.to_text`](stdlib.md)):

```lazarus
import std.Num

msg = "score: " ++ Num.to_text(score)
```

## Interpolated strings (`f"..."`)

An `f` prefix before the opening `"` enables expression interpolation. Curly braces `{}` embed an expression whose value is converted to a string automatically.

```lazarus
import std.Sys

name = "world"
n = 42
Sys.print(f"hello {name}, number {n + 1}")
```

Any expression is valid inside `{}`:

```lazarus
Sys.print(f"result: {compute(x) * 2}")
```

## Triple-quoted strings (`"""..."""`)

Three double quotes open and close a multi-line string. Leading indentation is stripped automatically.

```lazarus
text = """
    line one
    line two
    """
```

The indentation of the closing `"""` sets the baseline — all lines are dedented by that amount.

## Interpolated triple-quoted strings (`f"""..."""`)

Both features can be combined:

```lazarus
report = f"""
    Name:  {user_name}
    Score: {score}
    """
Sys.print(report)
```
