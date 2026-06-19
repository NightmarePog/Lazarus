--- Type inference and operator type-checking for the semantic pass.
---
--- The checker is **gradual**: anything whose type is unknown is `any` and flows
--- without error, so un-annotated code still type-checks. A concrete check fires
--- only when both sides of a relation have a known scalar type. `int` and
--- `float` are **distinct** and never convert implicitly (per the language
--- design), so mixing them is an error.
---
--- Types are represented internally as plain strings: `"int"`, `"float"`,
--- `"str"`, `"bool"`, or `"any"`.

local Error = require("error")
local Types = require("frontend.parser.types")

local TypeCheck = {}

local ARITH    = { PLUS = true, MINUS = true, MULTIPLY = true, DIVIDE = true, MODULO = true, POWER = true }
local ORDERING = { LESS = true, LESS_EQUAL = true, GREATER = true, GREATER_EQUAL = true }
local EQUALITY = { EQ = true, NEQ = true }
local LOGICAL  = { AND = true, OR = true }

--- Map a parsed `TypeRef` to an internal type string. Built-in scalars map to
--- themselves; everything else (a user type, or no annotation) is `any` for now
--- — user types become checkable once classes exist.
---@param ref TypeRef | nil
---@return string
function TypeCheck.resolve(ref)
    if not ref then return "any" end
    return Types.SCALARS[ref.name] and ref.name or "any"
end

---@param t string
---@return boolean
local function is_numeric(t) return t == "int" or t == "float" end

---@param node   Expr
---@param msg    string
---@param source string
local function fail(node, msg, source)
    Error.throw(Error.Type.TYPE_MISMATCH, msg, node.line, node.col, source, 1)
end

--- Infer an expression's type, throwing `TYPE_MISMATCH` on bad operands.
---@param node   Expr
---@param env    table<string, {vtype: string?}>  Scope mapping names to their type
---@param source string
---@return string
local function infer(node, env, source)
    local t = node.type

    if t == "LiteralExpr" then
        if node.kind == "string"  then return "str"  end
        if node.kind == "boolean" then return "bool" end
        return node.numeric or "any"  -- "int" | "float"
    end

    if t == "IdentifierExpr" then
        local entry = env[node.name]
        return (entry and entry.vtype) or "any"
    end

    if t == "CallExpr" then
        return "any"  -- call results are unchecked in this cut
    end

    if t == "UnaryExpr" then  -- prefix `not`
        local ot = infer(node.operand, env, source)
        if ot ~= "any" and ot ~= "bool" then
            fail(node, "Operator 'not' requires a 'bool' operand, but got '" .. ot .. "'", source)
        end
        return "bool"
    end

    if t == "BinaryExpr" then
        local lt = infer(node.left,  env, source)
        local rt = infer(node.right, env, source)
        local op = node.op

        if ARITH[op] or ORDERING[op] then
            if lt ~= "any" and not is_numeric(lt) then
                fail(node, "Operator '" .. op .. "' requires numeric operands, but the left side is '" .. lt .. "'", source)
            end
            if rt ~= "any" and not is_numeric(rt) then
                fail(node, "Operator '" .. op .. "' requires numeric operands, but the right side is '" .. rt .. "'", source)
            end
            if is_numeric(lt) and is_numeric(rt) and lt ~= rt then
                fail(node, "Operator '" .. op .. "' mixes '" .. lt .. "' and '" .. rt ..
                    "'; int and float do not convert implicitly", source)
            end
            -- Arithmetic yields the operand type; comparisons yield bool.
            if ARITH[op] then
                if lt == "any" or rt == "any" then return "any" end
                return lt
            end
            return "bool"
        end

        if op == "CONCAT" then
            if lt ~= "any" and lt ~= "str" then
                fail(node, "Operator '++' requires 'str' operands, but the left side is '" .. lt .. "'", source)
            end
            if rt ~= "any" and rt ~= "str" then
                fail(node, "Operator '++' requires 'str' operands, but the right side is '" .. rt .. "'", source)
            end
            return "str"
        end

        if LOGICAL[op] then
            if lt ~= "any" and lt ~= "bool" then
                fail(node, "Operator '" .. op .. "' requires 'bool' operands, but the left side is '" .. lt .. "'", source)
            end
            if rt ~= "any" and rt ~= "bool" then
                fail(node, "Operator '" .. op .. "' requires 'bool' operands, but the right side is '" .. rt .. "'", source)
            end
            return "bool"
        end

        if EQUALITY[op] then
            if lt ~= "any" and rt ~= "any" and lt ~= rt then
                fail(node, "Operator '" .. op .. "' compares '" .. lt .. "' with '" .. rt .. "'", source)
            end
            return "bool"
        end

        return "any"
    end

    return "any"
end

TypeCheck.infer = infer

--- Throw unless `actual` is assignable to `expected`. Gradual: `any` on either
--- side is always accepted.
---@param expected string
---@param actual   string
---@param node     Expr
---@param source   string
---@param what     string  Context for the message (e.g. "binding 'x'")
function TypeCheck.expect_assignable(expected, actual, node, source, what)
    if expected == "any" or actual == "any" then return end
    if expected ~= actual then
        fail(node, what .. " expects '" .. expected .. "' but got '" .. actual .. "'", source)
    end
end

--- Throw unless `node` is a `bool` (or `any`); used for conditions.
---@param node   Expr
---@param env    table
---@param source string
---@param what   string  Context for the message (e.g. "condition")
function TypeCheck.expect_bool(node, env, source, what)
    local t = infer(node, env, source)
    if t ~= "any" and t ~= "bool" then
        fail(node, "A " .. what .. " must be 'bool', but got '" .. t .. "'", source)
    end
end

return TypeCheck
