--- Expression rules, collected and mixed into the `Parser` class.
---
--- Precedence (low → high):
---   binary operators  (precedence-climbing; operator set in `operators.lua`)
---   unary             (prefix `not`)
---   call              (postfix `f(...)`)
---   primary           (literals, identifiers, grouped expressions)
---
--- Each rule module returns a table of `Parser` methods (e.g. `_primary`).
--- This file merges them into one table; `parser/init.lua` copies the result
--- onto the `Parser` class.
---
--- To add an infix operator, edit `operators.lua`. To add a new primary or
--- postfix form, add a module below.

---@type table<string, function>[]
local MODULES = {
    (require("frontend.parser.expressions.binary")),
    (require("frontend.parser.expressions.unary")),
    (require("frontend.parser.expressions.call")),
    (require("frontend.parser.expressions.primary")),
}

local exports = {}
for _, mod in ipairs(MODULES) do
    for name, fn in pairs(mod) do
        assert(exports[name] == nil, "expressions: duplicate rule method '" .. name .. "'")
        exports[name] = fn
    end
end

return exports
