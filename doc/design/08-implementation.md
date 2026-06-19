# 08 — Implementation & Lowering

How the v1 features are built on the existing five-stage pipeline
([`../pipeline.md`](../pipeline.md)) and lowered to Lua 5.0. This is a plan, not a
record — use the per-feature recipe in [`../adding-features.md`](../adding-features.md)
to land each piece.

## Where the work lands, by stage

| Stage | New responsibility |
|---|---|
| **Lexer** | New tokens: comments, `:` `.` `=>` `++` `+= -= *= /=` `== != < <= > >=` `% ^`, brackets `[ ] { }` already partly present, string interpolation pieces, keywords (02). |
| **Parser** | New nodes: class header (`extends`/`impl`), fields, `static` block, `init`, methods, `enum`, `trait`, `match`, `if`/`while`/`loop`/`for`, `import`, `extern`, `lua` block, list/map literals, calls/field access/index. |
| **Schematic** | The big addition — a **type checker**: types, inference for locals, field/method resolution, trait/override/abstract checks, exhaustiveness, strictness/`as`, casing enforcement. |
| **Optimizer** | Mostly unchanged; existing const-folding still applies to numeric expressions. |
| **Codegen** | Class→metatable lowering, enum/`match` lowering, collection offset & methods, `%` synthesis, interpolation, bundling multiple classes into one chunk. |

The type checker is the centre of gravity: today Schematic only does scope/name
analysis. Types are **erased** after Schematic, so Optimizer and Codegen see a
validated but otherwise plain AST.

## Suggested build order

Each step is shippable and testable on its own (front-to-back per feature):

1. **Lexical groundwork** — comments, the operator set, `bool`/`true`/`false`,
   `++`, compound assignment. (Lexer + small Parser/Codegen.)
2. **Control flow** — `if`/`while`/`loop`/`for`, `break`. No types needed beyond
   `bool` conditions.
3. **The type checker skeleton** — annotations on `fn` params/returns and bindings;
   `int`/`float`/`str`/`bool`; reject mismatches. Casing enforcement.
4. **Classes** — fields, `init`, methods/`self`, construction, metatable lowering.
5. **Inheritance** — `extends`, `override`/`super`, abstract, the metatable chain.
6. **Enums + `match`** — tagged values, exhaustiveness.
7. **Built-in `Option`/`Result`** — prelude enums, used by collections & errors.
8. **Collections** — `[T]`/`{K:V}` literals, 0-based offset, `.len/.push/.pop/.get`,
   `for-in`.
9. **Traits** — declaration, `impl` header, contract checking.
10. **Modules** — multi-file `import`, bundling, the entry call.
11. **Interop** — `extern`, `lua { }`, `as`, strictness.
12. **String interpolation** — last, since it is sugar over `++`.

## Lowering reference (Lua 5.0)

### Bindings and operators

```
base = 10            ->  local base = 10
mut total = 0        ->  local total = 0
total += base        ->  total = total + base
a ++ b               ->  a .. b
a % b                ->  (a - math.floor(a / b) * b)        -- 5.0 has no %
not done             ->  not done
a and b / a or b     ->  a and b / a or b
x != y               ->  x ~= y
"hi {name}!"         ->  "hi " .. name .. "!"
```

`int`/`float` both emit a Lua number on the 5.0 backend; the distinction is only
enforced at compile time. (On a future 5.4 backend, `int` literals/ops can emit
integer forms.)

### A class → plain table (no metatables)

> **Implementation decision (2026-06-19, supersedes the metatable sketch below).**
> Classes lower to a **plain table** with members indexed directly — **no
> metatables, no `__index`**. Reasons are purely mechanical (generated code is
> never hand-edited): metatable `__index` lookups are runtime overhead, and with
> tag/`kind` dispatch and inheritance deferred to v2 beta, the `__index` chain
> isn't needed. Instance methods use **explicit `self`**: `fn m(self,…)` →
> `function C.m(self, …)`, and a call `obj.m(args)` → `C.m(obj, args)` (the
> receiver's class is known statically). Construction `C(args)` → `C.new(args)`
> where `new` builds a plain table (no `setmetatable`).
>
> Members stay on the table (rather than all-locals) so the generated chunk can't
> exceed Lua's hard limits (~200 locals/scope, ~60 upvalues/function) and fail to
> load. A **future codegen optimization** may auto-prefer locals where provably
> under those limits, to reclaim the per-call hash-lookup cost — but the table
> form is the safe default. See `../pipeline.md` and the memory
> `codegen-class-table-model`.

```
// Point.laz
pub x: int = 0
pub y: int = 0
init(x: int, y: int) { self.x = x  self.y = y }
pub fn dist(self): float { return self.x * self.x + self.y * self.y }
```

lowers to roughly:

```lua
local Point = {}

function Point.new(x, y)              -- init: a plain table, no setmetatable
    local self = {}
    self.x = x
    self.y = y
    return self
end

function Point.dist(self)            -- explicit self, called as Point.dist(p)
    return self.x * self.x + self.y * self.y
end
```

- Construction `Point(3, 4)` emits `Point.new(3, 4)`.
- Method call `p.dist()` (implicit receiver) emits `Point.dist(p)`.
- Field default `x: int = 0` with no `init` assignment emits `self.x = 0` at the
  top of `new`.
- A **private** `init` simply means Codegen does not expose `Point.new` beyond its
  own chunk scope (and Schematic forbids external construction).

### Static members

```
static { count: int = 0   fn total(): int { return count } }
```

```lua
Point.count = 0
function Point.total() return Point.count end   -- no self
```

`static fn main()` in the entry file emits `function Main.main() ... end`, and the
bundler appends `Main.main()`.

### Inheritance, override, super, abstract

```
extends Actor
override fn update(self) { super.update()  self.hp = self.hp - 1 }
```

```lua
setmetatable(Enemy, { __index = Actor })   -- class-level inheritance
Enemy.__index = Enemy

function Enemy:update()
    Actor.update(self)                     -- super.update()
    self.hp = self.hp - 1
end
```

- Instance method lookup walks `instance -> Enemy -> Actor` via `__index`, which
  is exactly dynamic dispatch / overriding.
- `super.m()` emits `Parent.m(self)`.
- An **abstract** method emits a stub that `error()`s if reached; Schematic
  guarantees concrete subclasses override it and forbids constructing an abstract
  class, so the stub is a safety net, not a normal path.

### Enums and `match`

An enum value is a small tagged table; `match` becomes a tag dispatch.

```
enum Shape { Empty, Circle(float), Rect(int, int) }
Shape.Circle(2.0)
```

```lua
-- construction
{ tag = "Circle", [1] = 2.0 }
{ tag = "Empty" }
```

```
match shape {
    Circle(r)  => { area = pi * r * r },
    Rect(w, h) => { area = w * h },
    Empty      => { area = 0.0 },
}
```

```lua
local __t = shape.tag
if __t == "Circle" then
    local r = shape[1]
    area = pi * r * r
elseif __t == "Rect" then
    local w, h = shape[1], shape[2]
    area = w * h
elseif __t == "Empty" then
    area = 0.0
end   -- Schematic guarantees exhaustiveness, so no else is needed (or _ -> else)
```

**`Option`/`Result`** are prelude enums lowered the same way. As an optimization,
`Option` may use the bare-value/`nil` representation (`Some(x)` → `x`, `None` →
`nil`) since the checker already proves every use is guarded.

### Collections

```
xs = [10, 20, 30]            ->  { 10, 20, 30 }          -- Lua 1-based table
xs[0]                        ->  xs[0 + 1]               -- 0-based offset
xs[i]                        ->  xs[i + 1]
xs.len()                     ->  table.getn(xs)          -- 5.0 has no #
xs.push(v)                   ->  table.insert(xs, v)
xs.pop()                     ->  Option of table.remove(xs)
m.get(k)                     ->  Option of m[k]          -- nil -> None
for x in xs { }              ->  for _, x in ipairs(xs) do ... end
for k, v in m { }            ->  for k, v in pairs(m) do ... end
for (i=0; i<xs.len(); i+=1)  ->  i = 0; while i < table.getn(xs) do ...; i = i + 1 end
```

The constant `+1` offset on literal indices is folded by the Optimizer where the
index is a literal, so `xs[0]` costs nothing extra; variable indices emit `i + 1`.

### Interop

```
cc.term.write("hi")          ->  term.write("hi")        -- extern erased
lua { os.time() } as int     ->  (os.time())             -- block inlined, type forgotten
lua { print(name) }          ->  print(name)             -- sees Lazarus `name`
```

An `extern` block produces **no output** itself — it only informs the checker;
calls through it erase to the underlying Lua global.

## Bundling

The driver compiles the entry file and every imported class into **one** chunk:

- each class becomes a `local <Class> = {}` block with its methods;
- emitted member names are namespaced per class to avoid collisions;
- classes are emitted in dependency order so a parent exists before `extends`;
- top-level field defaults / `static` initializers run as the chunk loads;
- finally `<\Entry>.main()` is appended.

v1 emits **all** imported classes (no tree-shaking). Adding tree-shaking later is
a reachability pass over the call/reference graph starting at `main()` before
emission — it changes only *which* class members are emitted, not how they lower.

## Testing

Mirror the existing `spec/` layout (one spec per stage; see the conventions in
`spec/` and [`../adding-features.md`](../adding-features.md)). Each feature should
land with: lexer tokens, parsed AST shape, Schematic pass **and** fail cases
(type errors, non-exhaustive match, bad override, casing), emitted Lua, and at
least one end-to-end program in `integration_spec` that compiles and runs on a Lua
interpreter.
