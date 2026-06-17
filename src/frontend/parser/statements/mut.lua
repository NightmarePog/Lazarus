--- Statement handler for a `mut` local binding (no visibility).
---
--- Grammar: `mut <identifier> [ = <expression> ]`
---
--- Declares a mutable, function-local binding. Visibility modifiers
--- (`private`/`public`) are a top-level concern, so the bare `mut` form never
--- carries one.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding         = require("frontend.parser.statements.binding")

return StatementParser.new("MUTABLE", function(parser)
    return binding.read_binding(parser, nil, true,
        "Expected variable name after 'mut'")
end)
