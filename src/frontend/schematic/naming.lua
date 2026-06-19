--- Identifier casing rules. Values (functions, variables, parameters, loop
--- variables) are `snake_case`; type names are `PascalCase`, with the built-in
--- lowercase scalars (`int`/`float`/`str`/`bool`) exempt.

local Error = require("error")
local Types = require("frontend.parser.types")

local Naming = {}

---@param name string
---@return boolean
local function is_snake(name) return name:match("^[a-z_][a-z0-9_]*$") ~= nil end

---@param name string
---@return boolean
local function is_pascal(name) return name:match("^[A-Z][A-Za-z0-9]*$") ~= nil end

--- Enforce snake_case on a value name.
---@param name   string
---@param node   { line: integer?, col: integer? }
---@param source string
---@param what   string  Context for the message (e.g. "Function", "Binding")
function Naming.check_value(name, node, source, what)
    if not is_snake(name) then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            what .. " name '" .. name .. "' must be snake_case",
            node.line, node.col, source, #name)
    end
end

--- Enforce PascalCase on a type name (built-in scalars exempt).
---@param ref    TypeRef | nil
---@param source string
function Naming.check_type(ref, source)
    if not ref then return end
    if Types.SCALARS[ref.name] then return end
    if not is_pascal(ref.name) then
        Error.throw(Error.Type.SEMANTIC_ERROR,
            "Type name '" .. ref.name .. "' must be PascalCase",
            ref.line, ref.col, source, #ref.name)
    end
end

return Naming
