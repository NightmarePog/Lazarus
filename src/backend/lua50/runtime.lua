--- The collection/Option runtime prelude.
---
--- Lists, maps and Option are untyped, and codegen cannot tell them apart
--- statically, so each is a small **tagged table** (`{ kind = … }`) and every
--- operation dispatches on that tag at runtime through these `__lz_*` helpers.
--- The block is emitted once, at the top of a generated chunk, only when the
--- program actually uses a collection or Option (see `backend/lua50/init.lua`).
--- No metatables are used — consistent with the plain-table class model.
---
--- Representation:
---   list   `{ kind = "list", items = <1-based array> }`
---   map    `{ kind = "map",  items = <keyed table> }`
---   Option `{ kind = "some", value = v }` / `{ kind = "none" }`
---
--- (Uses Lua's `#` length operator; the generated code targets a 5.1+ host.)

local PRELUDE = [[
local function __lz_list(...)
    return { kind = "list", items = { ... } }
end
local function __lz_map(items)
    return { kind = "map", items = items }
end
local function __lz_some(v)
    return { kind = "some", value = v }
end
local function __lz_none()
    return { kind = "none" }
end
local function __lz_wrap(v)
    if v == nil then return __lz_none() end
    return __lz_some(v)
end
local function __lz_len(c)
    if c.kind == "list" then return #c.items end
    local n = 0
    for _ in pairs(c.items) do n = n + 1 end
    return n
end
local function __lz_push(c, v)
    c.items[#c.items + 1] = v
end
local function __lz_pop(c)
    local n = #c.items
    if n == 0 then return __lz_none() end
    local v = c.items[n]
    c.items[n] = nil
    return __lz_some(v)
end
local function __lz_get(c, k)
    local v = c.items[k]
    if v == nil then return __lz_none() end
    return __lz_some(v)
end
local function __lz_has(c, k)
    return c.items[k] ~= nil
end
local function __lz_idx_get(c, i)
    if c.kind == "list" then return c.items[i + 1] end
    return c.items[i]
end
local function __lz_idx_set(c, i, v)
    if c.kind == "list" then
        c.items[i + 1] = v
    else
        c.items[i] = v
    end
end
local function __lz_is_some(o)
    return o.kind == "some"
end
local function __lz_is_none(o)
    return o.kind == "none"
end
local function __lz_unwrap(o)
    if o.kind ~= "some" then error("unwrap of a None value") end
    return o.value
end
local function __lz_unwrap_or(o, d)
    if o.kind == "some" then return o.value end
    return d
end
local function __lz_str_find(s, sub)
    return (string.find(s, sub, 1, true))
end
local function __lz_argv(i)
    if arg == nil then return nil end
    return arg[i]
end
local function __lz_readfile(path)
    local f = io.open(path, "r")
    if f == nil then return nil end
    local data = f:read("*a")
    f:close()
    return data
end
local function __lz_each(c)
    if c.kind == "list" then
        local i = 0
        return function()
            i = i + 1
            if i > #c.items then return nil end
            return i - 1, c.items[i]
        end
    end
    return pairs(c.items)
end]]

return PRELUDE
