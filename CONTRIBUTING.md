# Contributing to Laze

Thanks for wanting to contribute. This document covers how to get set up, how the project is structured, and what to keep in mind before opening a PR.

## Getting started

You need Lua 5.4 installed. Clone the repo and verify everything works:

```sh
git clone https://github.com/NightmarePog/Laze
cd Laze
make selfhost
```

If `make selfhost` prints `fixpoint verified`, you're good. That command rebuilds the compiler from its own source and checks that the output is identical to the input binary.

## Project layout

```
compiler/     Laze compiler source (written in Laze)
std/          Standard library
doc/          Documentation
bin/          Compiled compiler binary (bin/lazec.lua)
examples/     Example programs
```

The compiler pipeline goes: Linker → Expander → Lexer → Parser → Schematic → Typecheck → Optimizer → Codegen → Bundler. Each stage has its own directory under `compiler/frontend/` or `compiler/backend/`.

## Adding a language feature

Read `doc/adding-features.md` before touching anything. The short version: one concept, one file, registered in a `HANDLERS` or `TOKENS` table. Never add to an existing `if/elseif` chain. Walk the pipeline front to back.

## Before submitting a PR

Run all three:

```sh
make selfhost   # must print "fixpoint verified"
make lint       # selene
make format     # stylua
```

All three must pass. If `make selfhost` fails, the compiler can no longer compile itself and the PR won't be merged.

## Commit style

Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`. Keep the subject line under 72 characters. No `Co-Authored-By` trailers.

## Opening issues

Bug reports and feature requests are welcome. For bugs, include the source file that triggers the issue and the error output. For feature requests, check the open issues first -- a lot of planned work is already tracked there.

## Code style

- No comments that describe what the code does -- only comments that explain why something non-obvious is happening
- Follow the patterns already in the file you're editing
- Stylua handles formatting -- don't fight it

## What's a good first contribution

Issues tagged [`good first issue`](https://github.com/NightmarePog/Laze/issues?q=is%3Aopen+label%3A%22good+first+issue%22) are scoped to be approachable without deep knowledge of the full pipeline.
