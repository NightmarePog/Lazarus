--- Statement emitter: converts a `Stmt` AST node to a Lua source string.

---@type fun(node: Expr): string
local emit_expr = require("backend.lua50.expr")

--- Indent every non-empty line of `text` by four spaces. Blank lines are left
--- empty so the output stays lint-clean (no trailing whitespace).
---@param text string
---@return string
local function indent(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        out[#out + 1] = line == "" and "" or "    " .. line
    end
    return table.concat(out, "\n")
end

---@type fun(node: Stmt): string
local emit_stmt

--- Emit a statement list as an indented block body, or `nil` when the block is
--- empty. Returned without leading/trailing newlines so callers control layout.
---@param stmts Stmt[]
---@return string?
local function emit_block(stmts)
    if #stmts == 0 then return nil end
    local lines = {}
    for _, stmt in ipairs(stmts) do
        lines[#lines + 1] = emit_stmt(stmt)
    end
    return indent(table.concat(lines, "\n"))
end

---@param node Stmt
---@return string
function emit_stmt(node)
    if node.type == "VariableDecl" then
        ---@cast node VariableDecl
        -- A reassignment, or a `public` binding (a global), is emitted without
        -- `local`. Everything else is a fresh local declaration.
        if node.reassign or node.visibility == "public" then
            local rhs = node.value and emit_expr(node.value) or "nil"
            return node.name .. " = " .. rhs
        end
        if node.value then
            return "local " .. node.name .. " = " .. emit_expr(node.value)
        end
        return "local " .. node.name
    end

    if node.type == "ExpressionStmt" then
        ---@cast node ExpressionStmt
        return emit_expr(node.expression)
    end

    if node.type == "FunctionDecl" then
        ---@cast node FunctionDecl
        local params = table.concat(node.params, ", ")
        local header = "local function " .. node.name .. "(" .. params .. ")"

        local body_lines = {}
        for _, stmt in ipairs(node.body) do
            body_lines[#body_lines + 1] = emit_stmt(stmt)
        end

        if #body_lines == 0 then
            return header .. "\nend"
        end
        return header .. "\n" .. indent(table.concat(body_lines, "\n")) .. "\nend"
    end

    if node.type == "ReturnStmt" then
        ---@cast node ReturnStmt
        if node.value then
            return "return " .. emit_expr(node.value)
        end
        return "return"
    end

    if node.type == "IfStmt" then
        ---@cast node IfStmt
        local parts = {}
        for i, clause in ipairs(node.clauses) do
            local kw = (i == 1) and "if " or "elseif "
            parts[#parts + 1] = kw .. emit_expr(clause.condition) .. " then"
            local body = emit_block(clause.body)
            if body then parts[#parts + 1] = body end
        end
        if node.else_body then
            parts[#parts + 1] = "else"
            local body = emit_block(node.else_body)
            if body then parts[#parts + 1] = body end
        end
        parts[#parts + 1] = "end"
        return table.concat(parts, "\n")
    end

    if node.type == "WhileStmt" then
        ---@cast node WhileStmt
        local parts = { "while " .. emit_expr(node.condition) .. " do" }
        local body = emit_block(node.body)
        if body then parts[#parts + 1] = body end
        parts[#parts + 1] = "end"
        return table.concat(parts, "\n")
    end

    if node.type == "LoopStmt" then
        ---@cast node LoopStmt
        local parts = { "while true do" }
        local body = emit_block(node.body)
        if body then parts[#parts + 1] = body end
        parts[#parts + 1] = "end"
        return table.concat(parts, "\n")
    end

    if node.type == "BreakStmt" then
        return "break"
    end

    if node.type == "ForStmt" then
        ---@cast node ForStmt
        -- The C-style `for` lowers to a `while` wrapped in a `do ... end` so the
        -- loop variable stays scoped to the loop; the step runs at the end of
        -- each iteration. An absent condition becomes `true`.
        local loop_body = {}
        for _, stmt in ipairs(node.body) do
            loop_body[#loop_body + 1] = stmt
        end
        if node.step then loop_body[#loop_body + 1] = node.step end

        local cond = node.condition and emit_expr(node.condition) or "true"
        local while_parts = { "while " .. cond .. " do" }
        local inner = emit_block(loop_body)
        if inner then while_parts[#while_parts + 1] = inner end
        while_parts[#while_parts + 1] = "end"
        local while_str = table.concat(while_parts, "\n")

        local do_body = {}
        if node.init then do_body[#do_body + 1] = emit_stmt(node.init) end
        do_body[#do_body + 1] = while_str

        return "do\n" .. indent(table.concat(do_body, "\n")) .. "\nend"
    end

    error("emit_stmt: unknown node type: " .. tostring(node.type))
end

return emit_stmt
