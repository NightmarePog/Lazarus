--- AST node for an `if` / `else if` / `else` statement.
---
--- `clauses` is the ordered list of conditional branches: the first is the `if`,
--- each subsequent entry an `else if`. Each clause is `{ condition, body }`.
--- `else_body` is the optional trailing `else` block (a `Stmt[]`, or `nil`).

---@class IfClause
---@field condition Expr
---@field body      Stmt[]

---@class IfStmt: Stmt
---@field type      "IfStmt"
---@field clauses   IfClause[]
---@field else_body Stmt[] | nil
---@field line      integer | nil
---@field col       integer | nil
local IfStmt = {}
IfStmt.__index = IfStmt

---@param clauses    IfClause[]
---@param else_body? Stmt[]
---@param line?      integer
---@param col?       integer
---@return IfStmt
function IfStmt.new(clauses, else_body, line, col)
    return setmetatable(
        { type = "IfStmt", clauses = clauses, else_body = else_body, line = line, col = col },
        IfStmt
    )
end

---@return string
function IfStmt:__tostring()
    return ("IfStmt(%d clause(s)%s)"):format(#self.clauses, self.else_body and " + else" or "")
end

return IfStmt
