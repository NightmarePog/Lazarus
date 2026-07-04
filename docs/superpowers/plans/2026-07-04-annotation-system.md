# Annotation System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compile-time annotation system: `@ClassName(Arg1, Arg2)` on declarations invokes handler methods (written in Lazarus) that inject new AST nodes before typechecking.

**Architecture:** The parser stores annotation metadata on the next declaration node. A new Expander pass, running between enum/interface collection and signature collection, loads handler modules via codegen-only compilation (no typecheck) and calls them via `pcall`. Injected nodes go through the full typecheck + codegen pipeline normally. The `Macro` stdlib class is the stable context + helper API for handler authors.

**Tech Stack:** Lazarus self-hosted compiler (`.laz` files in `compiler/`), Lua 5.4, no new dependencies.

---

## File map

| File | Action | Role |
|---|---|---|
| `compiler/frontend/parser/StmtParser.laz` | Modify | Generic `@Class(Args)` fallback in `parse_annotation()` |
| `std/annotation/Macro.laz` | Create | MacroContext class + static helpers (`fields`, `make_method`) |
| `compiler/Expander.laz` | Create | Handler compilation + annotation expansion pass |
| `compiler/Main.laz` | Modify | Split collection loop; run Expander between enum and sig passes |
| `std/annotation/Derive.laz` | Create | Reference `@Derive(Debug)` handler: injects `to_str()` |
| `examples/TestAnnotation.laz` | Create | Integration test |

---

### Task 1: Parser — generic annotation fallback

**Files:**
- Modify: `compiler/frontend/parser/StmtParser.laz:487-489`

`parse_annotation()` currently ends with `cursor.fail(...)` for any annotation that isn't `@auto` or `@platform`. Replace those 3 lines with a generic branch: parse `@ClassName(Arg1, Arg2, ...)` and set `annotation_class` / `annotation_args` attrs on the next declaration node.

- [ ] **Step 1: Replace lines 487–489 in `compiler/frontend/parser/StmtParser.laz`**

Current (lines 487–489):
```
    .cursor.fail("unknown annotation '@" ++ name.value ++ "'")
    return Ast.error_node()
}
```

New:
```laz
    mut args = []
    if .cursor.match("LEFT_BRACKET") {
        loop {
            if .cursor.check("RIGHT_BRACKET") { break }
            mut arg = .cursor.consume("IDENTIFIER", "Expected annotation argument (identifier)")
            args.push(arg.value)
            if not .cursor.match("COMMA") { break }
        }
        .cursor.consume("RIGHT_BRACKET", "Expected ')' after annotation arguments")
    }
    mut next_node = .parse_statement()
    next_node.set("annotation_class", name.value)
    next_node.set("annotation_args", args)
    return next_node
}
```

- [ ] **Step 2: Run tests and lint**

```sh
cd Lazarus && make test && make lint && make format
```

Expected: all tests pass. Annotations parse but the Expander doesn't exist yet — no behavioral change.

- [ ] **Step 3: Commit**

```sh
git add compiler/frontend/parser/StmtParser.laz
git commit -m "feat: parse generic @Class(Args) annotations on declarations"
```

---

### Task 2: Macro API

**Files:**
- Create: `std/annotation/Macro.laz`

`Macro` serves double duty: it IS the context object passed to handler methods (fields: `annotated`, `body`, `class_name`), and it exposes static helpers for reading the annotated class and building new AST nodes.

- [ ] **Step 1: Create directory**

```sh
mkdir -p Lazarus/std/annotation
```

- [ ] **Step 2: Write `std/annotation/Macro.laz`**

Full file content:

```laz
import compiler.frontend.parser.Ast
import compiler.frontend.parser.Node

// Context passed to every annotation handler method.
// Construct with Macro(annotated, body, class_name).
// Use Macro.fields(ctx) and Macro.make_method(...) as static helpers.

public annotated: dynamic
public body: List<dynamic>
public class_name: str

@auto
constructor(annotated: dynamic, body: List<dynamic>, class_name: str)

// Returns [{name, visibility}] for each non-static instance property in the class.
static fields(ctx: Macro): List<Map<str, str>> {
    mut result = []
    for node in ctx.body {
        if node.kind == "VariableDecl" {
            mut vis = node.attr("visibility").unwrap_or("")
            mut is_static = node.attr("is_static").unwrap_or(false)
            if vis != "" and not is_static {
                mut entry = [:]
                entry["name"] = node.child("name")
                entry["visibility"] = vis
                result.push(entry)
            }
        }
    }
    return result
}

// Returns a FunctionDecl node with a verbatim Lua body (same as the `lua` keyword).
// All params are typed dynamic. body_lua is emitted verbatim by the backend.
static make_method(name: str, params: List<str>, body_lua: str, visibility: str): dynamic {
    mut dyn_type = Ast.type_name("dynamic", [], 0, 0)
    mut param_types = []
    for p in params {
        param_types.push(Ast.type_name("dynamic", [], 0, 0))
    }
    return Ast.lua_decl(name, params, param_types, dyn_type, body_lua, false, visibility, 0, 0, [])
}
```

- [ ] **Step 3: Verify it compiles**

```sh
cd Lazarus && lua bin/lazarusc.lua std/annotation/Macro.laz --pkg-path .
```

Expected: no error. `Main.lua` is produced (just the class definition; Macro has no constructor entry point — that's fine).

- [ ] **Step 4: Commit**

```sh
git add std/annotation/Macro.laz
git commit -m "feat: add std/annotation/Macro API for annotation handlers"
```

---

### Task 3: Expander

**Files:**
- Create: `compiler/Expander.laz`

The Expander: walks a program's body, for each node with `annotation_class` set it finds the handler, compiles ALL modules via codegen-only (no typecheck), calls the handler method via `pcall`, injects returned nodes after the annotated node, clears the annotation attrs.

The handler is compiled from ALL modules (not just its deps) to ensure core stdlib (List, Map, etc.) is available in the handler's Lua environment — these are preloaded locals, not globals. The handler_cache is passed in from Main.laz so it's shared across modules in one compilation run.

- [ ] **Step 1: Write `compiler/Expander.laz`**

Full file content:

```laz
import std.Str
import backend.linker.Module
import backend.Codegen
import backend.Text
import frontend.parser.Node
import std.annotation.Macro

// Annotation expansion pass. Construct with the current module's class_name and
// a shared handler_cache (a Map from Main.laz — shared across modules by reference).

private class_name: str
private handler_cache: Map<str, dynamic>

@auto
constructor(class_name: str, handler_cache: Map<str, dynamic>)

public expand(program: Node, modules: List<Module>): unit {
    mut body = program.child("body")
    mut new_body = []
    for node in body {
        mut ann_opt = node.attr("annotation_class")
        if ann_opt.is_none() or ann_opt.unwrap() == "" {
            new_body.push(node)
        } else {
            new_body.push(node)
            mut ann_class = ann_opt.unwrap()
            mut args = node.attr("annotation_args").unwrap_or([])
            mut handler = .get_handler(ann_class, modules)
            mut ctx = Macro(node, body, .class_name)
            for arg in args {
                mut method_name = Str.lower(arg).unwrap_or(arg)
                mut injected = Expander.call_handler(handler, method_name, ctx)
                for n in injected {
                    new_body.push(n)
                }
            }
            node.set("annotation_class", "")
            node.set("annotation_args", [])
        }
    }
    program.set("body", new_body)
}

private get_handler(handler_class: str, modules: List<Module>): dynamic {
    if .handler_cache.has(handler_class) {
        return .handler_cache.get(handler_class).unwrap()
    }
    mut handler = Expander.compile_handler(handler_class, modules)
    .handler_cache[handler_class] = handler
    return handler
}

// Codegen all non-interface modules (no typecheck) into one Lua chunk, then load it.
// All modules are included so core stdlib (List, Map, Option, Result) are in scope as
// locals — they are NOT globals, so they must appear in the same Lua chunk as the handler.
static compile_handler(handler_class: str, modules: List<Module>): dynamic {
    mut blocks = []
    for m in modules {
        if not m.is_interface {
            mut cg = Codegen(m.class_name, m.imports, [:], [:], "")
            blocks.push(cg.class_block(m.ast))
        }
    }
    blocks.push("return " ++ handler_class)
    return Expander.load_lua(Text.join(blocks, "\n\n"))
}

static lua load_lua(src: str): dynamic {
    local chunk, err = load(src)
    if not chunk then
        error("failed to load annotation handler: " .. tostring(err))
    end
    local ok, result = pcall(chunk)
    if not ok then
        error("failed to initialize annotation handler: " .. tostring(result))
    end
    return result
}

static lua call_handler(handler: dynamic, method: str, ctx: dynamic): dynamic {
    local fn = handler[method]
    if not fn then
        error("annotation handler has no method '" .. method .. "'")
    end
    local ok, result = pcall(fn, handler, ctx)
    if not ok then
        error(tostring(result))
    end
    if result == nil then return List.__lz_list({}) end
    return result
}
```

- [ ] **Step 2: Verify it compiles**

```sh
cd Lazarus && lua bin/lazarusc.lua compiler/Expander.laz --pkg-path .
```

Expected: no error.

- [ ] **Step 3: Commit**

```sh
git add compiler/Expander.laz
git commit -m "feat: add Expander annotation expansion pass"
```

---

### Task 4: Wire Expander into Main.laz

**Files:**
- Modify: `compiler/Main.laz:8-88`

Split the single collection loop into three: (1) enums + interfaces only, (2) Expander pass on each module, (3) signatures. Then the existing analysis loop runs on the now-expanded ASTs. Signatures must come AFTER expansion so that any methods injected by handlers are visible to the typechecker.

- [ ] **Step 1: Add the Expander import**

In `compiler/Main.laz`, after line `import frontend.optimizer.Optimizer`, add:
```laz
import Expander
```

- [ ] **Step 2: Replace `build_file` (lines 58–88)**

Replace the entire `build_file` static method with:

```laz
static build_file(path: str, platform: str, pkg_path: str): unit {
    mut linker = Linker(path, pkg_path)
    mut modules = linker.link()

    mut variant_owner = [:]
    mut enums = [:]
    mut variant_arity = [:]
    mut variant_fields = [:]
    mut enum_type_params = [:]
    mut classes = [:]
    mut interfaces = [:]
    mut gated_externs = [:]

    for m in modules {
        Main.collect_enums(m.ast, variant_owner, enums, variant_arity, variant_fields, enum_type_params)
        Main.collect_interfaces(m.ast, interfaces, m.class_name)
    }

    mut handler_cache = [:]
    for m in modules {
        if not m.is_interface {
            Expander(m.class_name, handler_cache).expand(m.ast, modules)
        }
    }

    for m in modules {
        if not m.is_interface {
            Main.collect_signatures(m.ast, m.class_name, classes, platform, gated_externs)
        }
    }

    for m in modules {
        if not m.is_interface {
            Schematic.analyze(m.ast, m.source, m.class_name, m.imports, variant_owner, enums, variant_arity, gated_externs)
            Typecheck(m.source, m.class_name, m.imports, enums, classes, variant_fields, variant_owner, enum_type_params, interfaces).check(m.ast)
            Optimizer().optimize(m.ast)
        }
    }
    file = Sys.open("Main.lua", "w").unwrap()
    file.write(Bundler(modules, linker.entry_class(), variant_owner, platform).bundle())
    file.close()
}
```

- [ ] **Step 3: Run tests**

```sh
cd Lazarus && make test
```

Expected: all tests pass. The Expander runs for every module but does nothing when no annotations are present.

- [ ] **Step 4: Verify selfhost**

```sh
cd Lazarus && make selfhost
```

Expected: compiler rebuilds, fixpoint holds (two identical `bin/lazarusc.lua` outputs).

- [ ] **Step 5: Commit**

```sh
git add compiler/Main.laz
git commit -m "feat: run annotation Expander pass between enum and sig collection"
```

---

### Task 5: Derive handler

**Files:**
- Create: `std/annotation/Derive.laz`

Reference handler for `@Derive(Debug)`. Reads the class's public fields via `Macro.fields(ctx)` and injects a `to_str(): str` method that returns `"ClassName { fieldA=val fieldB=val }"`.

- [ ] **Step 1: Write `std/annotation/Derive.laz`**

Full file content:

```laz
import std.annotation.Macro

#object

// @Derive(Debug): inject to_str() that formats all public instance fields.
// Place @Derive(Debug) immediately before the constructor.
//
// Example output for class Point with fields x, y:
//   Point { x=3 y=7 }
debug(ctx: Macro): List<dynamic> {
    mut flds = Macro.fields(ctx)
    mut body = "return \"" ++ ctx.class_name ++ " {\""
    for f in flds {
        mut nm = f.get("name").unwrap_or("?")
        body = body ++ " .. \" " ++ nm ++ "=\" .. tostring(self." ++ nm ++ ")"
    }
    body = body ++ " .. \" }\""
    return [Macro.make_method("to_str", [], body, "public")]
}
```

The `body` string builds a Lua expression. For a class `Point` with fields `x` and `y`, it produces:
```lua
return "Point {" .. " x=" .. tostring(self.x) .. " y=" .. tostring(self.y) .. " }"
```

- [ ] **Step 2: Verify it compiles**

```sh
cd Lazarus && lua bin/lazarusc.lua std/annotation/Derive.laz --pkg-path .
```

Expected: no error.

- [ ] **Step 3: Commit**

```sh
git add std/annotation/Derive.laz
git commit -m "feat: add std/annotation/Derive handler for @Derive(Debug)"
```

---

### Task 6: Integration test and selfhost

**Files:**
- Create: `examples/TestAnnotation.laz`

Compile and run a file that uses `@Derive(Debug)`, verify output, then rebuild the self-hosted compiler to confirm the fixpoint still holds.

- [ ] **Step 1: Write `examples/TestAnnotation.laz`**

```laz
import std.annotation.Derive
import std.Sys

public x: int
public y: int

@Derive(Debug)
constructor(x: int, y: int) {
    .x = x
    .y = y
    Sys.print(.to_str())
}
```

- [ ] **Step 2: Compile it**

```sh
cd Lazarus && lua bin/lazarusc.lua examples/TestAnnotation.laz --pkg-path .
```

Expected: no compile error. `Main.lua` is produced.

- [ ] **Step 3: Run it**

```sh
lua Main.lua 3 7
```

Expected output:
```
TestAnnotation { x=3 y=7 }
```

If the output is wrong, check these in order:
1. `@Derive(Debug)` is on the line immediately before `constructor` — no blank lines between them
2. The annotation attrs (`annotation_class`, `annotation_args`) are being set (add a debug print in the Expander's `expand()` temporarily)
3. The `Macro.fields(ctx)` call — add a debug print in Derive.debug to verify `flds` has the right entries
4. The generated `body_lua` string — print it before calling `Macro.make_method`

- [ ] **Step 4: Run full test suite**

```sh
cd Lazarus && make test
```

Expected: all tests pass.

- [ ] **Step 5: Rebuild selfhost and verify fixpoint**

```sh
cd Lazarus && make selfhost
```

Expected: compiler rebuilds successfully, fixpoint holds.

- [ ] **Step 6: Commit**

```sh
git add examples/TestAnnotation.laz
git commit -m "feat: add TestAnnotation integration test for @Derive(Debug)"
```

---

## Known limitations (v1)

- Annotation arguments must be identifiers only — no string/number literals (`@Derive("debug")` is a parse error)
- Handlers cannot replace or remove the annotated node — injection only
- Handlers don't emit compiler warnings, only errors (via Lua `error()` in the handler, caught by `pcall`)
- Handler compilation skips typechecking — type errors in handler code surface as runtime errors during `pcall`, not at compile time
- `@Derive(Debug)` outputs field names and values but no formatting control
- Only one `@Annotation` per declaration at a time (stacking works: `@A` then `@B` on separate lines, each wraps `parse_statement()`)
