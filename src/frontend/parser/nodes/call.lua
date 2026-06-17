--- AST node for a function call (e.g. `f()`, `add(a, b)`).

---@class CallExpr: Expr
---@field type   "CallExpr"
---@field callee Expr          Expression that evaluates to the callee
---@field args   Expr[]        Argument expressions, in order
---@field line   integer | nil 1-based source line of the opening `(`
---@field col    integer | nil 1-based source column of the opening `(`
local CallExpr = {}
CallExpr.__index = CallExpr

---@param callee Expr
---@param args   Expr[]
---@param line?  integer
---@param col?   integer
---@return CallExpr
function CallExpr.new(callee, args, line, col)
    return setmetatable({ type = "CallExpr", callee = callee, args = args, line = line, col = col }, CallExpr)
end

---@return string
function CallExpr:__tostring()
    local parts = {}
    for i, arg in ipairs(self.args) do parts[i] = tostring(arg) end
    return ("CallExpr(%s, [%s])"):format(tostring(self.callee), table.concat(parts, ", "))
end

return CallExpr
