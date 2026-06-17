--- AST node for a `return` statement (`return [expr]`).

---@class ReturnStmt: Stmt
---@field type  "ReturnStmt"
---@field value Expr | nil    Returned expression, or `nil` for a bare `return`
---@field line  integer | nil 1-based source line of the `return` keyword
---@field col   integer | nil 1-based source column of the `return` keyword
local ReturnStmt = {}
ReturnStmt.__index = ReturnStmt

---@param value Expr | nil
---@param line? integer
---@param col?  integer
---@return ReturnStmt
function ReturnStmt.new(value, line, col)
    return setmetatable({ type = "ReturnStmt", value = value, line = line, col = col }, ReturnStmt)
end

---@return string
function ReturnStmt:__tostring()
    if self.value then
        return ("ReturnStmt(%s)"):format(tostring(self.value))
    end
    return "ReturnStmt()"
end

return ReturnStmt
