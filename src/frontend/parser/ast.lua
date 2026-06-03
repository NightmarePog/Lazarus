---@class AST
---@field type "Program"
---@field body Stmt[]
local AST = {}
AST.__index = AST

---@param body Stmt[]
---@return AST
function AST.new(body)
    return setmetatable({
        type = "Program",
        body = body
    }, AST)
end

return AST
