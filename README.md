# Lazarus

Lazarus is a simple programming language made mostly as a more readable version of Lua.

It transpiles directly to Lua source through a five-stage pipeline:
Lexer → Parser → Schematic (semantic checks) → Optimizer → Codegen.
See [`doc/pipeline.md`](doc/pipeline.md) for the full architecture, and
[`doc/adding-features.md`](doc/adding-features.md) for the standard recipe to
implement a new language feature.

The planned next major version (classes, a static type system, modules, and Lua
interop) is specified in [`doc/design/`](doc/design/).

## Compiler

`src/cli.lua` is the compiler entry point (`bin/lazarus` is a thin launcher):

```sh
bin/lazarus build <file.laz> [-o <out.lua>]   # compile to Lua (default: <file>.lua, -o - for stdout)
bin/lazarus check <file.laz>                  # parse + analyse, report errors only
bin/lazarus ast   <file.laz>                  # dump the optimised AST
bin/lazarus help                              # usage
bin/lazarus version                           # compiler version
```

See [`examples/`](examples/) for sample `.laz` programs paired with the Lua they
compile to.

## Development

```sh
make dev            # run the development REPL (src/repl.lua)
make build FILE=... # compile a .laz file via the CLI
make test           # run the busted test suite
make lint           # run selene
make format         # run stylua
make doc            # generate Doxygen docs
```

Set `LAZARUS_DEBUG=1` to append the internal Lua stack trace to error output.
