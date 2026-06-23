--- AST node for a C-style `for` loop, written without parentheses:
---   `for <init>; <condition>; <step> { body }`
---
--- Each of `init`, `condition` and `step` is optional (an empty clause is
--- `nil`). `init` and `step` are statements; `condition` is an expression.

---@class ForStmt: Stmt
---@field type      "ForStmt"
---@field init      VariableDecl | nil
---@field condition Expr | nil
---@field step      Stmt | nil
---@field body      Stmt[]
---@field line      integer | nil
---@field col       integer | nil
local ForStmt = {}
ForStmt.__index = ForStmt

---@param init      VariableDecl | nil
---@param condition Expr | nil
---@param step      Stmt | nil
---@param body      Stmt[]
---@param line?     integer
---@param col?      integer
---@return ForStmt
function ForStmt.new(init, condition, step, body, line, col)
    return setmetatable(
        { type = "ForStmt", init = init, condition = condition, step = step, body = body, line = line, col = col },
        ForStmt
    )
end

---@return string
function ForStmt:__tostring()
    return ("ForStmt(%d stmts)"):format(#self.body)
end

return ForStmt
