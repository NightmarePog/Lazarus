--- AST node for a `while` loop (`while <condition> { body }`).

---@class WhileStmt: Stmt
---@field type      "WhileStmt"
---@field condition Expr
---@field body      Stmt[]
---@field line      integer | nil
---@field col       integer | nil
local WhileStmt = {}
WhileStmt.__index = WhileStmt

---@param condition Expr
---@param body      Stmt[]
---@param line?     integer
---@param col?      integer
---@return WhileStmt
function WhileStmt.new(condition, body, line, col)
    return setmetatable(
        { type = "WhileStmt", condition = condition, body = body, line = line, col = col },
        WhileStmt
    )
end

---@return string
function WhileStmt:__tostring()
    return ("WhileStmt(%d stmts)"):format(#self.body)
end

return WhileStmt
