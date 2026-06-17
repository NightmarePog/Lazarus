--- Binary (infix) operator precedence table.
---
--- This is the single place to register an infix operator. Each entry maps a
--- token type to its precedence level — a higher number binds tighter. Every
--- operator listed here is parsed left-associatively by `binary.lua`.
---
--- To add an operator (e.g. division):
---   1. add its symbol + token type to `frontend/lexer/keywords.lua`
---   2. add one line here, e.g. `DIVIDE = 2`
--- No other parser code needs to change.

---@type table<string, integer>
return {
    PLUS     = 1,
    MINUS    = 1,
    MULTIPLY = 2,
}
