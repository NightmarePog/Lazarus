--- Best-effort "is this expression provably **not** a boolean?".
---
--- The language is untyped and has no truthiness — a condition must be an actual
--- boolean. Without types the check is necessarily conservative: it fires only
--- when a value *cannot* be a boolean (a number/string literal, a collection, an
--- arithmetic/concat result, or a built-in that returns a number/Option), and
--- stays silent on anything that might be one (a name, a field, a call). This
--- catches the common mistakes (`if 5`, `if list.len()`, `if map.get(k)`) without
--- the false positives a full inference pass would risk.

--- Binary operators whose result is a number (never a boolean).
local ARITHMETIC = {
    PLUS = true,
    MINUS = true,
    MULTIPLY = true,
    DIVIDE = true,
    MODULO = true,
    POWER = true,
}

--- Built-in methods whose result is provably not a boolean (see expr.lua
--- `BUILTIN_METHODS`). `is_some`/`is_none`/`has` return booleans and are allowed;
--- `unwrap`/`unwrap_or` yield an unknown inner value and are left alone.
local NON_BOOL_BUILTIN = {
    len = "a number (the result of '.len()')",
    get = "an Option (the result of '.get()')",
    pop = "an Option (the result of '.pop()')",
}

--- A short description of why `node` is non-boolean, or nil when it could be a
--- boolean (and the condition is therefore allowed).
---@param node Expr
---@return string | nil
local function non_bool_reason(node)
    if node.type == "LiteralExpr" then
        ---@cast node LiteralExpr
        if node.kind == "number" then return "a number" end
        if node.kind == "string" then return "a string" end
        return nil -- boolean literal: fine
    end
    if node.type == "ListExpr" then return "a list" end
    if node.type == "MapExpr" then return "a map" end
    if node.type == "BinaryExpr" then
        ---@cast node BinaryExpr
        if ARITHMETIC[node.op] then return "an arithmetic value" end
        if node.op == "CONCAT" then return "a string" end
        return nil -- comparison / `and` / `or`: boolean
    end
    if node.type == "CallExpr" then
        ---@cast node CallExpr
        if node.callee.type == "MemberExpr" then
            ---@cast node CallExpr
            local field = node.callee.field
            ---@cast field string
            return NON_BOOL_BUILTIN[field]
        end
    end
    return nil
end

return { non_bool_reason = non_bool_reason }
