--- Identifier casing rules. Values (functions, variables, parameters, loop
--- variables) are `snake_case`. The language is untyped, so there are no type
--- names to case-check.

local Error = require("error")

local Naming = {}

---@param name string
---@return boolean
local function is_snake(name) return name:match("^[a-z_][a-z0-9_]*$") ~= nil end

--- Enforce snake_case on a value name.
---@param name   string
---@param node   { line: integer?, col: integer? }
---@param source string
---@param what   string  Context for the message (e.g. "Function", "Binding")
function Naming.check_value(name, node, source, what)
    if not is_snake(name) then
        Error.throw(
            Error.Type.SEMANTIC_ERROR,
            what .. " name '" .. name .. "' must be snake_case",
            node.line,
            node.col,
            source,
            #name
        )
    end
end

return Naming
