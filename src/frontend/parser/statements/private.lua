--- Statement handler for `private` bindings.
---
--- Grammar: `private [ mut ] <identifier> [ = <expression> ]`
---
--- Immutable by default; `mut` opts into reassignability. The initialiser is
--- required unless `mut` is present.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding         = require("frontend.parser.statements.binding")

return StatementParser.new("PRIVATE", function(parser)
    local mutable = parser:_match("MUTABLE")
    return binding.read_binding(parser, "private", mutable,
        "Expected variable name after 'private'")
end)
