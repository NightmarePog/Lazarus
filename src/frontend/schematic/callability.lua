--- The one static fact the untyped checker tracks about a value: whether it is
--- provably **not** a function. A binding initialised with such a value can never
--- be called, so `expressions/call.lua` can reject `f()` up front.
---
--- Literals, arithmetic/comparison/logical/concat results and `not` are always
--- scalars or booleans — never functions. Anything else (a call result, another
--- name, a field access) is unknown and treated as possibly callable.

--- Expression kinds whose value is provably not a function.
---@type table<string, boolean>
local NON_FUNCTION = {
    LiteralExpr = true,
    BinaryExpr = true,
    UnaryExpr = true,
}

--- True when `node`'s value is statically known not to be a function.
---@param node Expr | nil
---@return boolean
local function is_noncallable(node) return node ~= nil and NON_FUNCTION[node.type] == true end

return { is_noncallable = is_noncallable }
