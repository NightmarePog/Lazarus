# Control Flow

All control flow constructs are statement-based. They do not produce values. Results come from assignments inside the branches or from `return`.

Conditions must be `bool`. There is no truthiness: `if x` where `x` is an `int` is a type error.

## if

```
if n < 0 {
    Sys.print("negative")
} else if n == 0 {
    Sys.print("zero")
} else {
    Sys.print("positive")
}
```

No parentheses around the condition. Braces are required.

## while

```
mut i = 0
while i < 10 {
    i += 1
}
```

## loop

`loop` is an explicit infinite loop. Exit with `break`:

```
loop {
    mut line = Sys.read_line().unwrap_or("")
    if line == "quit" { break }
    handle(line)
}
```

This reads clearer than `while true` when the exit condition is in the middle of the body.

## for -- counting

The C-style counting loop. Each clause is separated by semicolons:

```
for i = 0; i < 10; i += 1 {
    Sys.print(f"step {i}")
}
```

The loop variable (`i` here) is a fresh mutable binding scoped to the loop. Any clause can be empty. The most common use is iterating over an index.

## for-in -- iteration

Walk lists and maps with `for...in`:

```
names = ["alice", "bob", "carol"]
for name in names {
    Sys.print(name)
}
```

For maps and for lists when you need the index, use two variables:

```
for i, x in names {
    Sys.print(f"{i}: {x}")
}

scores = ["alice": 95, "bob": 87]
for name, score in scores {
    Sys.print(f"{name} scored {score}")
}
```

## match

`match` branches on an enum value. Every variant must be covered, or you get a compile error. Use `_` to match anything you do not need to handle individually:

```
enum Status { Active, Pending, Closed(str) }

match status {
    Active     => { Sys.print("active") }
    Pending    => { Sys.print("pending") }
    Closed(r)  => { Sys.print(f"closed: {r}") }
}
```

Payload variants bind their data as new variables in the arm body. There are no guards in match arms. If you need a condition, use an `if` inside the arm:

```
match result {
    Ok(n) => {
        if n > 100 {
            Sys.print("big")
        } else {
            Sys.print(f"got {n}")
        }
    }
    Err(msg) => { Sys.print(f"error: {msg}") }
}
```

`match` on `Option<T>` is very common:

```
match find_user(id) {
    Some(user) => { greet(user) }
    None       => { Sys.print("not found") }
}
```

## break

`break` exits the nearest enclosing loop. There is no `continue`.

```
for x in items {
    if x < 0 { break }
    process(x)
}
```

To skip an item without exiting the loop, wrap the body in an `if`:

```
for x in items {
    if x > 0 {
        process(x)
    }
}
```

## return

`return` exits the current function and optionally passes a value back:

```
classify(n: int): str {
    if n < 0  { return "negative" }
    if n == 0 { return "zero" }
    return "positive"
}
```

A function that returns `unit` can use a bare `return` to exit early:

```
log(msg: str): unit {
    if .quiet { return }
    Sys.print(msg)
}
```
