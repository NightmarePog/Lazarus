--- AST node for a map literal: `["k0": v0, "k1": v1]` (key/value pairs). The
--- empty map is written `[:]` to distinguish it from the empty list `[]`.

---@class MapEntry
---@field key   Expr
---@field value Expr

---@class MapExpr: Expr
---@field type    "MapExpr"
---@field entries MapEntry[]    Key/value pairs, in source order
---@field line    integer | nil 1-based source line of the `[`
---@field col     integer | nil 1-based source column of the `[`
local MapExpr = {}
MapExpr.__index = MapExpr

---@param entries MapEntry[]
---@param line?   integer
---@param col?    integer
---@return MapExpr
function MapExpr.new(entries, line, col)
    return setmetatable({ type = "MapExpr", entries = entries, line = line, col = col }, MapExpr)
end

---@return string
function MapExpr:__tostring()
    return ("MapExpr(%d entries)"):format(#self.entries)
end

return MapExpr
