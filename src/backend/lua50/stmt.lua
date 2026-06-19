--- Statement emitter: converts a `Stmt` AST node to a Lua source string.
---
--- Top-level statements are class **members** (`emit_member`): functions become
--- `function C.name(...)` and bindings become `C.name = value`. Statements inside
--- a body (`emit_stmt`) emit as ordinary Lua; nested functions and `local`
--- bindings declare locals in the codegen `Context` so that references to them
--- stay bare while references to class members are qualified as `C.member`.

local emit_expr = require("backend.lua50.expr")
local Context   = require("backend.lua50.context")

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

--- Emit the body of a function, with its parameters declared as locals in a
--- fresh scope. Returns the joined, indented body (or nil when empty).
---@param params string[]
---@param body   Stmt[]
---@return string?
local function emit_fn_body(params, body)
    Context.push_scope()
    for _, p in ipairs(params) do Context.declare_local(p) end
    local out = emit_block(body)
    Context.pop_scope()
    return out
end

---@param node Stmt
---@return string
function emit_stmt(node)
    if node.type == "VariableDecl" then
        ---@cast node VariableDecl
        -- A reassignment rebinds an existing name (possibly a class member, which
        -- is qualified). A fresh binding is a new local.
        if node.reassign then
            local rhs = node.value and emit_expr(node.value) or "nil"
            return Context.emit_name(node.name) .. " = " .. rhs
        end
        Context.declare_local(node.name)
        if node.value then
            return "local " .. node.name .. " = " .. emit_expr(node.value)
        end
        return "local " .. node.name
    end

    if node.type == "FieldAssign" then
        ---@cast node FieldAssign
        return emit_expr(node.target) .. " = " .. emit_expr(node.value)
    end

    if node.type == "ExpressionStmt" then
        ---@cast node ExpressionStmt
        return emit_expr(node.expression)
    end

    if node.type == "FunctionDecl" then
        ---@cast node FunctionDecl
        -- A function nested inside a body is an ordinary local function.
        Context.declare_local(node.name)
        local params = table.concat(node.params, ", ")
        local header = "local function " .. node.name .. "(" .. params .. ")"
        local body = emit_fn_body(node.params, node.body)
        if not body then return header .. "\nend" end
        return header .. "\n" .. body .. "\nend"
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

        -- Emit init first so the loop variable is declared local before the
        -- condition/step/body reference it.
        local do_body = {}
        if node.init then do_body[#do_body + 1] = emit_stmt(node.init) end

        local cond = node.condition and emit_expr(node.condition) or "true"
        local while_parts = { "while " .. cond .. " do" }
        local inner = emit_block(loop_body)
        if inner then while_parts[#while_parts + 1] = inner end
        while_parts[#while_parts + 1] = "end"
        do_body[#do_body + 1] = table.concat(while_parts, "\n")

        return "do\n" .. indent(table.concat(do_body, "\n")) .. "\nend"
    end

    error("emit_stmt: unknown node type: " .. tostring(node.type))
end

--- Emit a top-level statement as a class **member**: a self-less function as a
--- static method `function C.name(...)`, a binding as a static field
--- `C.name = value`. Anything else falls back to ordinary statement emission.
---@param node Stmt
---@return string
local function emit_member(node)
    local C = Context.class

    if node.type == "FunctionDecl" then
        ---@cast node FunctionDecl
        local params = table.concat(node.params, ", ")
        local header = "function " .. C .. "." .. node.name .. "(" .. params .. ")"
        local body = emit_fn_body(node.params, node.body)
        if not body then return header .. "\nend" end
        return header .. "\n" .. body .. "\nend"
    end

    if node.type == "VariableDecl" then
        ---@cast node VariableDecl
        local rhs = node.value and emit_expr(node.value) or "nil"
        return C .. "." .. node.name .. " = " .. rhs
    end

    if node.type == "ConstructorDecl" then
        ---@cast node ConstructorDecl
        -- Lowers to `function C.new(params) local self = {} <body> return self end`
        -- — a plain table, no metatable.
        Context.push_scope()
        for _, p in ipairs(node.params) do Context.declare_local(p) end
        Context.declare_local("self")
        local lines = { "local self = {}" }
        for _, s in ipairs(node.body) do lines[#lines + 1] = emit_stmt(s) end
        lines[#lines + 1] = "return self"
        Context.pop_scope()

        local params = table.concat(node.params, ", ")
        return "function " .. C .. ".new(" .. params .. ")\n"
            .. indent(table.concat(lines, "\n")) .. "\nend"
    end

    return emit_stmt(node)
end

return { emit_stmt = emit_stmt, emit_member = emit_member }
