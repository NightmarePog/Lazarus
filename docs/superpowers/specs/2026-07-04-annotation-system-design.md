# Lazarus Annotation System — Design Spec

**Date:** 2026-07-04  
**Status:** Approved

---

## Goal

A compile-time metaprogramming layer. Users import annotation handler classes written in Lazarus and apply them with `@ClassName(Arg1, Arg2)`. Handlers run between parsing and typechecking; they inject new AST nodes into the annotated class body.

---

## Syntax

```laz
import std.annotation.Derive

@Derive(Debug)
class Point {
    public x: int
    public y: int
    constructor(x: int, y: int) { .x = x  .y = y }
}
// After expansion: Point gets a generated to_str() method
```

- `@ClassName(Arg1, Arg2)` — annotation with one or more arguments (identifiers only; no string/number literals in args for v1)
- Arguments are comma-separated identifiers inside parens: `@Derive(Debug, Clone)`
- Multiple annotations on one declaration are allowed; each stacks independently
- Annotations are valid on any top-level declaration (class members: methods, fields, enums)
- `@auto` and `@platform` remain built-in and are handled before the generic path

---

## Dispatch Model

`@Derive(Debug, Clone)` on a node calls, in order:
1. `Derive.debug(node: dynamic): List<dynamic>`
2. `Derive.clone(node: dynamic): List<dynamic>`

Each argument lowercases to a method name on the handler class. If a method is missing, it is a compile error at the `@Annotation` line (not a silent skip).

Returned `List<dynamic>` is injected **after** the annotated node in the class body. The original node is always kept.

---

## Architecture

### 1. Parser (`compiler/frontend/parser/StmtParser.laz`)

Extend `parse_annotation()` — after the `@auto` and `@platform` built-in branches, add a generic fallback:

```
if name is unknown annotation:
    parse optional (Arg1, Arg2, ...) — identifiers only
    call parse_statement() to get the next declaration node
    set "annotation_class" = name on the node
    set "annotation_args"  = [arg1, arg2, ...] on the node
    return the node
```

Multiple annotations on the same declaration are handled naturally: each `@Foo` call wraps `parse_statement()` which may itself call `parse_annotation()` again for the next `@Bar`.

### 2. Pipeline change (`compiler/Main.laz`)

The current compile loop processes all modules together:
```
collect_sigs for all → schematic for all → typecheck for all → optimize for all → bundle
```

The new loop processes modules **one at a time in dependency order**:
```
handler_cache = [:]
for each module M in dependency order:
    expand_annotations(M, handler_cache)   // new
    collect_sigs(M)
    schematic.analyze(M)
    typecheck(M)
    optimize(M)
    lua_block = codegen.class_block(M)
    handler_cache[M.class_name] = load(lua_block + "\nreturn " + M.class_name)()
bundle all class blocks
```

Handlers are always dependencies of the modules that use them — so by the time module M is processed, any handler it references is already in `handler_cache`.

### 3. Expander (`compiler/frontend/Expander.laz`)

New class. Called once per module before schematic.

Responsibilities:
- Walk `module.ast.body`
- For each node with `annotation_class` set:
  - Look up the handler in `handler_cache`; error if missing (import was not resolved)
  - For each arg in `annotation_args`:
    - Lowercase the arg → method name
    - Call `handler.method_name(node)` via a `lua` inline helper using `pcall`
    - On `pcall` failure: raise a `AnnotationError` at the annotation's line/col
    - Collect returned nodes
  - Inject the collected nodes after the annotated node in the body
- Strip `annotation_class` / `annotation_args` attrs from nodes (so later stages don't see them)

```laz
class Expander {
    private handler_cache: Map<str, dynamic>

    @auto
    constructor(handler_cache: Map<str, dynamic>)

    public expand(ast: Node): unit { ... }

    lua call_handler(handler: dynamic, method: str, node: dynamic): dynamic {
        local fn = handler[method]
        if not fn then return nil end
        local ok, result = pcall(fn, handler, node)
        if not ok then error(result) end
        return result
    }
}
```

### 4. Macro API (`compiler/frontend/Macro.laz`)

Stable helper module for handler authors. Hides internal node format.

```laz
#object

// Read helpers
class_name(node: dynamic): str
fields(node: dynamic): List<Map<str, str>>   // [{name, visibility, type_name}]
methods(node: dynamic): List<Map<str, str>>  // [{name, visibility, is_static}]

// Build helpers
make_method(name: str, params: List<str>, body_lua: str, visibility: str): dynamic
make_field(name: str, visibility: str): dynamic
```

`make_method` returns a `FunctionDecl` node with `raw_body` set (same as `lua` keyword methods) so the emitter outputs the body verbatim. This keeps handler authors from needing to build expression AST trees.

### 5. Example handler (`std/annotation/Derive.laz`)

```laz
import compiler.frontend.Macro
import std.Str

#object

debug(node: dynamic): List<dynamic> {
    mut nm    = Macro.class_name(node)
    mut flds  = Macro.fields(node)
    mut parts = []
    for f in flds {
        mut name = f.get("name").unwrap_or("?")
        parts.push("\" " ++ name ++ "=\" .. tostring(self." ++ name ++ ")")
    }
    mut body = "return \"" ++ nm ++ " {\" .. " ++ Str.join(parts, " .. ") ++ " .. \" }\""
    return [Macro.make_method("to_str", [], body, "public")]
}
```

---

## Error Handling

| Situation | Behaviour |
|---|---|
| `@Derive(Debug)` but `Derive` is not imported | Compile error: "annotation handler 'Derive' not found — is it imported?" |
| `Derive.debug` method missing on handler | Compile error: "annotation 'Derive' has no handler for argument 'Debug'" |
| Handler crashes during `pcall` | Compile error at the `@Derive` source line, with the handler's error message appended |
| Handler returns a non-list | Compile error: "annotation handler 'Derive.debug' must return List<dynamic>" |

---

## Files

| File | Action | Responsibility |
|---|---|---|
| `compiler/frontend/parser/StmtParser.laz` | Modify | Generic `@Class(Args)` annotation parsing |
| `compiler/frontend/Expander.laz` | Create | Annotation expansion pass |
| `compiler/frontend/Macro.laz` | Create | Stable node-reading and node-building API |
| `compiler/Main.laz` | Modify | Per-module compile loop; wire in Expander |
| `std/annotation/Derive.laz` | Create | `@Derive(Debug)` example handler |
| `examples/TestAnnotation.laz` | Create | Integration test |

---

## Out of Scope (v1)

- String or number literals as annotation arguments (identifiers only)
- Annotations on local variables or function parameters
- Handlers replacing or removing the annotated node (inject-only)
- Handlers emitting compiler warnings (only errors)
- Annotations on non-class-member nodes (imports, enums at top level)
