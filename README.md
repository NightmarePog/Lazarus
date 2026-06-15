# Lazarus

Lazarus is a simple programming language made mostly as a more readable version of Lua.

It transpiles directly to Lua source through a five-stage pipeline:
Lexer → Parser → Schematic (semantic checks) → Optimizer → Codegen.
See [`doc/pipeline.md`](doc/pipeline.md) for the full architecture.

## Usage

```sh
make dev     # run the development REPL (src/repl.lua)
make test    # run the busted test suite
make lint    # run selene
make format  # run stylua
make doc     # generate Doxygen docs
```

Set `LAZARUS_DEBUG=1` to append the internal Lua stack trace to error output.
