--- Binary (infix) operator precedence table.
---
--- This is the single place to register an infix operator. Each entry maps a
--- token type to its precedence level — a higher number binds tighter. Every
--- operator listed here is parsed left-associatively by `binary.lua`.
---
--- To add an operator (e.g. division):
---   1. add its symbol + token type to `frontend/lexer/keywords.lua`
---   2. add one line here, e.g. `DIVIDE = 5`
--- No other parser code needs to change.
---
--- Levels (low → high): logical `or`/`and`, then comparison/equality, then
--- additive, then multiplicative. The unary `not` (in `unary.lua`) and postfix
--- calls bind tighter than every operator here, mirroring Lua's precedence.

---@type table<string, integer>
return {
    OR            = 1,
    AND           = 2,
    EQ            = 3,
    NEQ           = 3,
    LESS          = 3,
    LESS_EQUAL    = 3,
    GREATER       = 3,
    GREATER_EQUAL = 3,
    CONCAT        = 4,
    PLUS          = 4,
    MINUS         = 4,
    MULTIPLY      = 5,
    DIVIDE        = 5,
    MODULO        = 5,
    POWER         = 6,
}
