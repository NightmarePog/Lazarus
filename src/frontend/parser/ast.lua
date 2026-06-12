--- Root AST node produced by the parser (`Program`).

---@class AST
---@field type "Program"
---@field body Stmt[]   Top-level statement list
local AST = {}
AST.__index = AST

---@param body Stmt[]
---@return AST
function AST.new(body)
    return setmetatable({ type = "Program", body = body }, AST)
end

---@return string
function AST:__tostring()
    return ("Program(%d statements)"):format(#self.body)
end

return AST
