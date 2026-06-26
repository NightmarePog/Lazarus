# Examples

Each `.laz` file here is a Lazarus program, paired with the `.lua` file the
compiler produces from it. The generated `.lua` files are checked in so you can
read the input and the output side by side without running anything.

A file **is a class** named after the file (`Showcase.laz` → class `Showcase`),
so filenames are `PascalCase`. The output is a plain Lua table whose top-level
functions and bindings are members; the chunk ends with `return <Class>`.

| Source | Output | Shows off |
|---|---|---|
| [`Arithmetic.laz`](Arithmetic.laz) | [`Arithmetic.lua`](Arithmetic.lua) | Constant folding + propagation — `base`/`scaled` fold to literals at compile time |
| [`Functions.laz`](Functions.laz) | [`Functions.lua`](Functions.lua) | Function declarations, calls, nested calls, the `main()` entry point |
| [`Mutability.laz`](Mutability.laz) | [`Mutability.lua`](Mutability.lua) | `mut` locals reassigned in place vs immutable bindings; a `public mut` member |
| [`Showcase.laz`](Showcase.laz) | [`Showcase.lua`](Showcase.lua) | Everything at once — folding, `public`/`private`, `mut`, params, nested functions, strings, recursion-safe self-reference |
| [`multi/Main.laz`](multi/Main.laz) + [`multi/Box.laz`](multi/Box.laz) | [`multi/Main.lua`](multi/Main.lua) | **Multiple files** — `import`, cross-class construction (`Box(7)`) and instance-method dispatch (`b.read()`) bundled into one chunk |

## Multi-file programs

A program can span several `.laz` files. A file `import`s another class to use it,
and the compiler **links** the whole import graph into a single self-contained Lua
chunk (dependencies emitted first, no `require`). You build the **entry** file; its
imports are pulled in automatically:

```sh
bin/lazarus build examples/multi/Main.laz   # follows `import Box`, bundles both
lua -e 'local M = dofile("examples/multi/Main.lua"); print(M.result)'   # -> 7
```

Construction (`Box(7)`) and static calls (`Box.unit()`) lower to `Box.new(...)` /
`Box.unit(...)`; an instance call across files (`b.read()`) lowers to Lua's colon
`b:read()`, which works because each instance carries its methods (no metatables).

## How the output is produced

Each `.lua` file was generated with the compiler CLI:

```sh
bin/lazarus build examples/Arithmetic.laz   # -> examples/Arithmetic.lua
```

To regenerate all of them:

```sh
for f in examples/*.laz; do bin/lazarus build "$f"; done
```

## Running an example

The generated Lua runs on a stock `lua` interpreter. Programs with a `main`
function call it automatically (the compiler appends `<Class>.main()`), and the
chunk returns the class table, so you capture it to inspect results:

```sh
lua examples/Showcase.lua
```

```sh
lua -e 'local S = dofile("examples/Showcase.lua"); print(S.answer, S.label)'   # -> 74   lazarus
lua -e 'local A = dofile("examples/Arithmetic.lua"); print(A.total)'           # -> 27
lua -e 'local M = dofile("examples/Mutability.lua"); print(M.counter)'         # -> 10
```

Notice how, for example, `private base = 2 * 3 + 1` becomes `Arithmetic.base = 7`
in the output: the optimizer folds the constant expression and propagates `base`
into every place it is used (`r = r + 7`, `total = total + 20`, …) before codegen
ever runs.
