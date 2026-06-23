--- AST node for a `break` statement (exits the nearest enclosing loop).

---@class BreakStmt: Stmt
---@field type "BreakStmt"
---@field line integer | nil
---@field col  integer | nil
local BreakStmt = {}
BreakStmt.__index = BreakStmt

---@param line? integer
---@param col?  integer
---@return BreakStmt
function BreakStmt.new(line, col)
    return setmetatable({ type = "BreakStmt", line = line, col = col }, BreakStmt)
end

---@return string
function BreakStmt.__tostring()
    return "BreakStmt"
end

return BreakStmt
