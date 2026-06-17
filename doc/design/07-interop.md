# 07 — Lua Interop

Lazarus runs on Lua and must call existing Lua APIs — ComputerCraft's `term`,
`turtle`, `redstone`; OpenComputers components; the Lua standard library. Two
mechanisms cover this: **typed `extern` declarations** for safe, checked calls,
and a **raw `lua { }` escape** for everything else.

## `extern` — typed bindings to Lua

An `extern` block describes the shape of an external Lua global so calls to it
are type-checked and then erased (they compile to direct Lua calls). Externs are
collected in **importable declaration files** — effectively a typed stdlib you
`import` — rather than redeclared in every file.

```
// cc.laz  ->  a class "cc" that bundles ComputerCraft externs
extern term {
    fn write(s: str)
    fn setCursorPos(x: int, y: int)
    fn getSize(): int
    fn clear()
}

extern turtle {
    fn forward(): bool
    fn turnLeft(): bool
}

extern colors {        // values and nested tables, not just functions
    white: int
    red: int
}
```

Used after import, qualified through the declaration class:

```
import cc

fn main() {
    cc.term.clear()
    cc.term.setCursorPos(1, 1)
    cc.term.write("hello")
    cc.turtle.forward()
    c = cc.colors.white
}
```

What `extern` may declare:
- **functions** with typed parameters and an optional return (`fn write(s: str)`,
  `fn getSize(): int`),
- **values** (`white: int`),
- **nested tables** (a block inside a block) for APIs exposed as sub-tables.

Externs are **assertions about Lua you provide** — the compiler trusts the
signatures (it cannot check the real Lua), and erases them to direct calls
(`cc.term.write("hi")` → `term.write("hi")`). A wrong signature is a runtime bug,
exactly as in hand-written Lua, but everything you route through the typed extern
is checked against it.

## `lua { }` — the raw escape

For anything not modelled by an `extern`, drop to raw Lua. A `lua { }` block:

- is **expression-valued** — it yields its last Lua expression;
- can **see surrounding Lazarus variables** by name;
- produces type **`any`**, which you pin with `as` (required in strict mode).

```
name = "al"

t = lua { os.time() } as int          // value out, asserted to int
lua { print(name) }                   // statement use, sees `name`, no value
busy = lua { os.clock() > deadline } as bool
```

Use `lua { }` sparingly — it is the unsafe boundary. Prefer adding an `extern`
signature when you call something repeatedly.

## `as` and strictness (recap)

Values from `lua { }` and unmodelled externs are `any`. Under the default
**strict** mode you must `as`-assert an `any` to a concrete type before using it
in typed code; `as` is an **unchecked** assertion (no runtime check — you vouch
for it). In **loose** mode `any` flows freely and `as` is optional. Full rules in
[04-types-and-data.md](04-types-and-data.md).

## The 1-based boundary

Lazarus lists are **0-based** and the compiler offsets them onto Lua's 1-based
tables. Data that comes **from** Lua through `extern`/`lua { }` is **raw Lua and
stays 1-based** — the compiler does not silently re-index it. If you pull a Lua
table across the boundary and want Lazarus list semantics, copy/convert it
explicitly. This keeps interop predictable instead of magic.

## Targets and interop

`extern`/`lua { }` are how target-specific APIs stay out of the core language:
ComputerCraft and OpenComputers expose different globals, so their bindings live
in different `extern` stdlib files you import per project. The language itself
makes no assumption about which Lua environment it runs in beyond the **Lua 5.0**
(later 5.4) core.
