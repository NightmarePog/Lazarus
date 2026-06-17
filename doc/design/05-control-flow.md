# 05 — Control Flow

All control flow is **statement-based** — `if`, `match`, loops yield no value;
results come back through assignment or `return`. Conditions are `bool` (no
truthiness). Blocks are always braced.

## `if` / `else if` / `else`

No parentheses around the condition; braces required:

```
if a > b and ready {
    best = a
} else if a == b {
    best = a
} else {
    best = b
}
```

## `while`

```
while x != 0 {
    x = step(x)
}
```

## `loop`

An explicit infinite loop (clearer than `while true`):

```
loop {
    line = read()
    if line == "quit" { break }
    handle(line)
}
```

## `for` — C-style

The counting loop is the three-part C form. It needs compound assignment
(`i += 1`) and `.len()`, both of which exist:

```
for (i = 0; i < xs.len(); i += 1) {
    use(xs[i])
}
```

- The init binds a loop variable (a fresh `i`), the condition is `bool`, the step
  is any statement.
- Lowers to a Lua `while` loop (not Lua's numeric `for`), because the C form is
  more general; see [08-implementation.md](08-implementation.md).

## `for ... in` — collection iteration

For walking lists and maps (the only clean way to iterate a map):

```
for x in xs {            // list elements
    use(x)
}

for k, v in ages {       // map entries
    use(k, v)
}
```

Lowers to Lua's generic `for ... in` with the appropriate iterator.

## `match`

Covered in [04-types-and-data.md](04-types-and-data.md). Recap: statement form,
`=>` arms with block bodies, **exhaustive** (or `_`), bare patterns that bind
payloads, **no guards** in v1.

```
match shape {
    Circle(r)  => { area = 3.14159 * r * r },
    Rect(w, h) => { area = w * h },
    _          => { area = 0.0 },
}
```

## `break`

`break` exits the nearest enclosing loop. **There is no `continue`** in v1 (Lua
5.0 has neither `continue` nor `goto`, and we chose not to synthesize it) — skip
an iteration with an `if` around the remainder of the body:

```
for x in xs {
    if not valid(x) {
        // skip
    } else {
        process(x)
    }
}
```

## `return`

```
fn classify(self, n: int): str {
    if n < 0 { return "neg" }
    if n == 0 { return "zero" }
    return "pos"
}
```

A function with a return type must return on every path (Schematic checks this).
A function with no return type returns nothing; a bare `return` exits early. As
in the current language, `return` must be the last statement of its block.

## What is intentionally absent in v1

- `continue` (deferred — see above).
- `if`/`match` as **expressions** (we chose statement semantics): write to a
  variable in each branch instead of `x = if ... { } else { }`.
- Numeric ranges (`0..n`) as values: the C-style `for` covers counting; `for-in`
  covers collections.
