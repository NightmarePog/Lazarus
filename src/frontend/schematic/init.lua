--- Semantic analysis pass: walks the AST and enforces semantic rules.
---
--- Rules enforced:
---   • Duplicate declarations in the same scope are an error.
---   • References to undeclared identifiers are an error.

local Error      = require("error")
local check_expr = require("frontend.schematic.expr")

---@param ast    AST
---@param source string
local function analyze(ast, source)
    ---@type table<string, {kind: string}>
    local symbols = {}

    for _, stmt in ipairs(ast.body) do
        if stmt.type == "VariableDecl" then
            ---@cast stmt VariableDecl
            if symbols[stmt.name] then
                Error.throw(Error.Type.SEMANTIC_ERROR,
                    "Duplicate declaration '" .. stmt.name .. "'",
                    stmt.line, stmt.col, source, #stmt.name)
            end
            if stmt.value then check_expr(stmt.value, symbols, source) end
            symbols[stmt.name] = { kind = "variable" }

        elseif stmt.type == "ConstantDecl" then
            ---@cast stmt ConstantDecl
            if symbols[stmt.name] then
                Error.throw(Error.Type.SEMANTIC_ERROR,
                    "Duplicate declaration '" .. stmt.name .. "'",
                    stmt.line, stmt.col, source, #stmt.name)
            end
            check_expr(stmt.value, symbols, source)
            symbols[stmt.name] = { kind = "constant" }

        elseif stmt.type == "ExpressionStmt" then
            ---@cast stmt ExpressionStmt
            -- A bare expression cannot be lowered to a valid Lua statement
            -- (the language has no call syntax yet, the only legal expression
            -- statement in Lua). Reject it rather than emit code that fails to
            -- load. Relax this once call expressions are introduced.
            check_expr(stmt.expression, symbols, source)
            Error.throw(Error.Type.SEMANTIC_ERROR,
                "Bare expressions are not valid statements",
                stmt.line, stmt.col, source)
        end
    end
end

return { analyze = analyze }
