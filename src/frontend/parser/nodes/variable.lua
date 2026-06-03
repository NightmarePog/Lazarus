---@class VariableDecl: Stmt
local VariableDecl = {}

function VariableDecl.new(name, value)
    return { type = "VariableDecl", name = name, value = value }
end

return VariableDecl
