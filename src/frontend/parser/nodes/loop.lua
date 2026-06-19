--- AST node for an explicit infinite loop (`loop { body }`).

---@class LoopStmt: Stmt
---@field type "LoopStmt"
---@field body Stmt[]
---@field line integer | nil
---@field col  integer | nil
local LoopStmt = {}
LoopStmt.__index = LoopStmt

---@param body  Stmt[]
---@param line? integer
---@param col?  integer
---@return LoopStmt
function LoopStmt.new(body, line, col)
    return setmetatable({ type = "LoopStmt", body = body, line = line, col = col }, LoopStmt)
end

---@return string
function LoopStmt:__tostring()
    return ("LoopStmt(%d stmts)"):format(#self.body)
end

return LoopStmt
