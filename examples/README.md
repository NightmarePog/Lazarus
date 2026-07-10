# Examples

Each `.class.laz` file here is a runnable Lazarus program, paired with the `.lua` file the compiler produces. The generated `.lua` files are checked in so you can read the input and output side by side without running the compiler.

| Source | Output | Shows |
|---|---|---|
| [`Arithmetic.class.laz`](Arithmetic.class.laz) | [`Arithmetic.lua`](Arithmetic.lua) | Constant folding -- `base` and `scaled` fold to literals at compile time and are propagated into every use site |
| [`Functions.class.laz`](Functions.class.laz) | [`Functions.lua`](Functions.lua) | Static functions, nested calls, static fields |
| [`Mutability.class.laz`](Mutability.class.laz) | [`Mutability.lua`](Mutability.lua) | `mut` locals vs immutable bindings |
| [`Showcase.class.laz`](Showcase.class.laz) | [`Showcase.lua`](Showcase.lua) | A larger example: static fields, `private`/`public`, nested functions, instance methods, f-strings |
| [`TestInterp.class.laz`](TestInterp.class.laz) | | F-strings and triple-quoted strings |
| [`multi/Main.class.laz`](multi/Main.class.laz) + [`multi/Box.class.laz`](multi/Box.class.laz) | | Multi-file: `import`, construction across files, instance method dispatch |

## Running an example

The compiler writes `<ClassName>.lua` to the current directory:

```sh
lua bin/lazarusc.lua examples/Showcase.class.laz
lua Showcase.lua
```

For examples that do not define `static main()`, the compiler still emits a valid chunk. Inspect the result by loading the file:

```sh
lua -e 'local A = dofile("examples/Arithmetic.lua"); print(A.total)'     -- 27
lua -e 'local S = dofile("examples/Showcase.lua"); print(S.answer, S.label)'   -- 74  lazarus
lua -e 'local M = dofile("examples/Mutability.lua"); print(M.counter)'   -- 10
```

## Multi-file programs

The `multi/` directory shows how import works across files. `Main.class.laz` imports `Box`, which the compiler resolves to `Box.class.laz` in the same directory:

```sh
lua bin/lazarusc.lua examples/multi/Main.class.laz
lua Main.lua
```

The compiler follows all imports transitively and bundles everything into one chunk, with no `require` in the output.

## What the output looks like

The optimizer folds constant expressions before codegen runs. In `Arithmetic.class.laz`:

```
private static base   = 2 * 3 + 1    // folds to 7
private static scaled = (base + 3) * 2  // folds to 20
```

The emitted Lua contains the folded values directly. Reading the `.lua` output next to the source is a good way to understand how the compiler lowers code.
