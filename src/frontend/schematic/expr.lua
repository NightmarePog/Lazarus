--- Expression checker: validates identifier references within an `Expr` node.

local Error = require("error")

---@param node    Expr
---@param symbols table<string, {kind: string}>
---@param source  string
local function check_expr(node, symbols, source)
    if node.type == "IdentifierExpr" then
        ---@cast node IdentifierExpr
        if not symbols[node.name] then
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Undeclared identifier '" .. node.name .. "'",
                node.line, node.col, source, #node.name)
        end
    elseif node.type == "BinaryExpr" then
        ---@cast node BinaryExpr
        check_expr(node.left,  symbols, source)
        check_expr(node.right, symbols, source)
    end
end

return check_expr
