--- Per-generation codegen context for the `file = class` model.
---
--- A file lowers to a class table `C`; its top-level functions and bindings are
--- members emitted as `function C.name(...)` and `C.name = value`. Inside a
--- member body, a reference to another member must be qualified (`C.other`),
--- while locals and parameters stay bare. This context tracks the member set and
--- a stack of local scopes so `emit_name` can make that distinction.

local Context = {}

Context.class = "Main"
---@type table<string, boolean>
Context.members = {}
-- Names of the class's instance methods (a subset of `members`). A call whose
-- callee is `obj.<name>` where `<name>` is here lowers to receiver-passing
-- dispatch `C.<name>(obj, …)`.
---@type table<string, boolean>
Context.instance_methods = {}

-- Instance properties in declaration order: each `{ name, value }` where `value`
-- is the default-initialiser Expr (or `nil`). These are *not* members (they live
-- on the instance, reached only via `.field`); their defaults are emitted at the
-- top of `C.new`.
---@type { name: string, value: Expr | nil }[]
Context.properties = {}

-- Set once a list/map/Option construct is emitted, so the chunk knows to prepend
-- the `__lz_*` runtime prelude (and omit it from collection-free programs).
---@type boolean
Context.uses_collections = false

-- Stack of local scopes; the top entry is the innermost. Each scope inherits
-- visible locals from its parent via `__index`, mirroring Lua closure capture.
local scopes = { {} }

local function current() return scopes[#scopes] end

--- Reset for a fresh generation over class `class` with the given member names.
---@param class            string
---@param members          table<string, boolean>
---@param instance_methods table<string, boolean>?
---@param properties       { name: string, value: Expr | nil }[]?
function Context.reset(class, members, instance_methods, properties)
    Context.class = class
    Context.members = members
    Context.instance_methods = instance_methods or {}
    Context.properties = properties or {}
    Context.uses_collections = false
    scopes = { {} }
end

--- Enter a new local scope (a function body), inheriting outer locals.
function Context.push_scope() scopes[#scopes + 1] = setmetatable({}, { __index = current() }) end

--- Leave the innermost local scope.
function Context.pop_scope() scopes[#scopes] = nil end

--- Declare a local name (parameter, `local` binding, loop variable) in the
--- current scope so later references to it are not mistaken for a member.
---@param name string
function Context.declare_local(name) current()[name] = true end

--- Emit an identifier: qualified as `C.name` when it names a member that is not
--- shadowed by a local, otherwise the bare name (locals, params, globals).
---@param name string
---@return string
function Context.emit_name(name)
    if current()[name] then return name end
    if Context.members[name] then return Context.class .. "." .. name end
    return name
end

return Context
