--- AST node for an index assignment statement: `object[index] = value`
--- (list element write or map insert/update). Compound forms (`xs[i] += 1`)
--- desugar to a plain assignment with a `BinaryExpr` value, like other
--- assignments.

---@class IndexAssign: Stmt
---@field type   "IndexAssign"
---@field target IndexExpr     The `object[index]` being written
---@field value  Expr          The value expression
---@field line   integer | nil 1-based source line
---@field col    integer | nil 1-based source column
local IndexAssign = {}
IndexAssign.__index = IndexAssign

---@param target IndexExpr
---@param value  Expr
---@param line?  integer
---@param col?   integer
---@return IndexAssign
function IndexAssign.new(target, value, line, col)
    return setmetatable(
        { type = "IndexAssign", target = target, value = value, line = line, col = col },
        IndexAssign
    )
end

---@return string
function IndexAssign:__tostring()
    return ("IndexAssign(%s = %s)"):format(tostring(self.target), tostring(self.value))
end

return IndexAssign
