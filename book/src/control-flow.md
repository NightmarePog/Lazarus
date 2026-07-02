# Control Flow

## `if` / `else if` / `else`

```lazarus
if x > 0 {
    Sys.print("positive")
} else if x == 0 {
    Sys.print("zero")
} else {
    Sys.print("negative")
}
```

Conditions do not require parentheses. Braces are required.

## `while`

Loops while the condition is true:

```lazarus
mut i = 0
while i < 10 {
    i += 1
}
```

## `loop`

An unconditional loop. Use `break` to exit:

```lazarus
loop {
    mut line = Sys.read_line().unwrap_or("")
    if line == "quit" {
        break
    }
    Sys.print(line)
}
```

## `break`

Exits the nearest enclosing `while` or `loop`:

```lazarus
mut found = false
loop {
    if .check() {
        found = true
        break
    }
}
```

## `for ... in`

Iterates over a collection. One variable binds the value; two variables bind key and value for maps:

```lazarus
// list
for item in items {
    Sys.print(item)
}

// map (key, value)
for key, val in table {
    Sys.print(key ++ ": " ++ val)
}
```

## C-style `for`

A traditional init/condition/step loop:

```lazarus
for i = 0; i < 10; i += 1 {
    Sys.print(i)
}
```

Any of the three parts may be omitted:

```lazarus
for ; .running ; {
    .tick()
}
```

## `match`

Pattern-matches a value against a list of arms. Arms are tried top-to-bottom; the first matching arm runs.

```lazarus
match status {
    0 => { Sys.print("ok") }
    1 => { Sys.print("error") }
    _ => { Sys.print("unknown") }
}
```

### Value patterns

Any expression can be used as a pattern; it is compared with `==` to the scrutinee:

```lazarus
match code {
    200 => { Sys.print("OK") }
    404 => { Sys.print("not found") }
    _   => { Sys.print("other") }
}
```

### Enum variant patterns

`PascalCase` names are matched as enum variants (see [Enums](enums.md)):

```lazarus
match opt {
    Some(v) => { Sys.print(v) }
    None    => { Sys.print("absent") }
}
```

### Guards

Any arm can carry an `if <expr>` guard that must also be true:

```lazarus
match n {
    x if x > 100 => { Sys.print("big") }
    x if x > 0   => { Sys.print("small") }
    _             => { Sys.print("non-positive") }
}
```

### Wildcard `_`

`_` matches anything and must be the last arm:

```lazarus
match event {
    Click => { .handle_click() }
    _     => {}
}
```
