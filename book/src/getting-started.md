# Getting Started

## Requirements

- Lua 5.x installed and on your `PATH`
- The Lazarus compiler binary: `bin/lazarusc.lua`

## Compiling a file

```sh
lua bin/lazarusc.lua MyProgram.laz
```

This writes `Main.lua` to the current working directory.

```sh
lua Main.lua
```

The makefile exposes a convenience target:

```sh
make selfbuild FILE=MyProgram.laz
```

## Your first program

Create `Hello.laz`:

```lazarus
import std.Sys

constructor() {
    Sys.print("hello, world")
}
```

Compile and run:

```sh
lua bin/lazarusc.lua Hello.laz
lua Main.lua
```

## Entry point

The compiler calls the constructor of the root file automatically. There is no separate `main` function — the constructor of the file you pass to `lazarusc` is the entry point.

## Naming conventions

The compiler enforces these naming rules:

| Kind | Convention | Example |
|------|-----------|---------|
| File / class | `PascalCase` | `MyClass.laz` |
| Function / method | `snake_case` | `do_thing` |
| Variable / binding | `snake_case` | `my_value` |
| Enum variant | `PascalCase` | `Some`, `None` |
