# Examples

Each `.laz` file here is a Lazarus program, paired with the `.lua` file the
compiler produces from it. The generated `.lua` files are checked in so you can
read the input and the output side by side without running anything.

| Source | Output | Shows off |
|---|---|---|
| [`arithmetic.laz`](arithmetic.laz) | [`arithmetic.lua`](arithmetic.lua) | Constant folding + propagation — `base`/`scaled` fold to literals at compile time |
| [`functions.laz`](functions.laz) | [`functions.lua`](functions.lua) | Function declarations, calls, nested calls, the `main()` entry point |
| [`mutability.laz`](mutability.laz) | [`mutability.lua`](mutability.lua) | `mut` locals reassigned in place vs immutable bindings; a `public mut` global |
| [`showcase.laz`](showcase.laz) | [`showcase.lua`](showcase.lua) | Everything at once — folding, `public`/`private`, `mut`, params, nested functions, strings, recursion-safe self-reference |

## How the output is produced

Each `.lua` file was generated with the compiler CLI:

```sh
bin/lazarus build examples/arithmetic.laz   # -> examples/arithmetic.lua
```

To regenerate all of them:

```sh
for f in examples/*.laz; do bin/lazarus build "$f"; done
```

## Running an example

The generated Lua runs on a stock `lua` interpreter. Programs with a `main`
function call it automatically (the compiler appends `main()`):

```sh
lua examples/showcase.lua
```

Public bindings become Lua globals, so you can inspect results:

```sh
lua -e 'dofile("examples/showcase.lua"); print(answer, label)'   # -> 74   lazarus
lua -e 'dofile("examples/arithmetic.lua"); print(total)'         # -> 27
lua -e 'dofile("examples/mutability.lua"); print(counter)'       # -> 10
```

Notice how, for example, `private base = 2 * 3 + 1` becomes `local base = 7` in
the output: the optimizer folds the constant expression and propagates `base`
into every place it is used (`r = r + 7`, `total = total + 20`, …) before
codegen ever runs.
