--- Code generator: walks the AST and emits Lua 5.0 source text.

local emit_stmt = require("backend.lua50.stmt")

---@class Codegen
---@field ast AST
local Codegen = {}
Codegen.__index = Codegen

---@param ast AST
---@return Codegen
function Codegen.new(ast)
    return setmetatable({ ast = ast }, Codegen)
end

---@return string
function Codegen:generate()
    local lines = {}
    for _, stmt in ipairs(self.ast.body) do
        lines[#lines + 1] = emit_stmt(stmt)
    end
    return table.concat(lines, "\n")
end

return Codegen
