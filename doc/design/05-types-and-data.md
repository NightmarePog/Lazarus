# Types and Data

## Option

`Option<T>` represents a value that might not be there. It is an enum with two variants: `Some(T)` holds a value, and `None` means absence. There is no `nil` in Laze: whenever something might be missing, the type is `Option`.

```
find(items: List<str>, target: str): Option<int> {
    mut i = 0
    for item in items {
        if item == target { return Some(i) }
        i += 1
    }
    return None
}
```

The standard library provides `Option` as `std.Option`. Use `match` to handle both cases:

```
match find(names, "alice") {
    Some(i) => { Sys.print(f"found at {i}") }
    None    => { Sys.print("not found") }
}
```

Or use the helpers when the failure case is simple:

```
import std.Option

idx = find(names, "alice")

// unwrap_or returns a default when None
i = Option.unwrap_or(idx, -1)

// unwrap panics on None
i = Option.unwrap(idx)
```

The `?` operator propagates `Option` out of the current function. If the value is `None`, the function returns `None` immediately. If it is `Some(v)`, it unwraps to `v`:

```
parse_two(s: str): Option<int> {
    parts = Str.split(s, ",")
    a = parts.get(0)?
    b = parts.get(1)?
    return Some(Str.to_int(a).unwrap_or(0) + Str.to_int(b).unwrap_or(0))
}
```

## Result

`Result<T>` represents either success or failure. `Ok(T)` holds the success value. `Err(str)` holds an error message:

```
read_config(path: str): Result<str> {
    content = Sys.read_file(path)
    match content {
        Some(s) => { return Ok(s) }
        None    => { return Err(f"cannot read {path}") }
    }
}
```

Use it the same way you use Option:

```
import std.Result

match read_config("settings.toml") {
    Ok(cfg)  => { parse(cfg) }
    Err(msg) => { Sys.print(f"error: {msg}") }
}

// or with helpers
cfg = Result.unwrap_or(read_config("settings.toml"), "")
```

`?` works on Result too. A `None` propagates as `None`; an `Err` propagates as `Err`:

```
load_and_parse(path: str): Result<Config> {
    raw = read_config(path)?
    return parse_config(raw)
}
```

## Lists

A list is an ordered sequence of values with a fixed element type. The type is written `List<T>`:

```
names: List<str> = ["alice", "bob", "carol"]
nums: List<int>  = [1, 2, 3, 4, 5]
empty: List<int> = []
```

List indices are 0-based. The compiler adjusts them to Lua's 1-based tables automatically:

```
first = names[0]    // "alice"
last  = names[2]    // "carol"
names[1] = "beth"
```

Common operations:

```
names.push("dave")
popped = names.pop()             // Option<str>
found  = names.get(10)           // Option<str>, safe -- no panic on out of range
n      = names.len()
empty  = names.is_empty()
has    = names.contains("alice")
```

Higher-order operations:

```
import std.Num

squares = nums.map(fn(x: int): int = x * x)
evens   = nums.filter(fn(x: int): bool = x % 2 == 0)
total   = nums.fold(0, fn(acc: int, x: int): int = acc + x)
first3  = nums.slice(0, 3)
joined  = names.join(", ")       // "alice, bob, carol"
```

List comprehensions build a list from another sequence:

```
squares = [x * x for x in nums]
big     = [x for x in nums if x > 10]
```

## Maps

A map is a key-value store. The type is written `Map<K, V>`:

```
scores: Map<str, int> = ["alice": 95, "bob": 87]
empty: Map<str, int>  = [:]
```

Access and mutation:

```
s = scores.get("alice")      // Option<int>
scores["carol"] = 91
scores.delete("bob")
n = scores.len()
has = scores.has("alice")
```

Iterating:

```
for name, score in scores {
    Sys.print(f"{name}: {score}")
}
```

Map comprehensions:

```
doubled = [k: v * 2 for k, v in scores]
high    = [k: v for k, v in scores if v >= 90]
keys    = scores.keys()      // List<str>
vals    = scores.values()    // List<int>
```

## Custom enums

Enums are declared inside a class file. They can carry payload data in their variants:

```
enum Token {
    Number(int),
    Word(str),
    Punct(str),
    End
}

static describe(t: Token): str {
    match t {
        Number(n) => { return f"number {n}" }
        Word(w)   => { return f"word '{w}'" }
        Punct(p)  => { return f"punct '{p}'" }
        End       => { return "end" }
    }
}
```

Construct a variant by name:

```
t1 = Number(42)
t2 = Word("hello")
t3 = End
```

Variants are always matched exhaustively. A `match` that does not cover every variant is a compile error. The `_` wildcard catches anything not listed:

```
match t {
    Number(n) => { process_number(n) }
    _         => { }
}
```

## Generics

You can write generic functions that work over any type. Type parameters go in angle brackets after the function name:

```
static first<T>(items: List<T>): Option<T> {
    return items.get(0)
}

static zip<A, B>(as: List<A>, bs: List<B>): List<List<dynamic>> {
    mut result = []
    for i, a in as {
        match bs.get(i) {
            Some(b) => { result.push([a, b]) }
            None    => { }
        }
    }
    return result
}
```

The standard library enums `Option<T>` and `Result<T>` use generics in exactly this way.
