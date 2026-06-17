--- Statement handler for `public` bindings.
---
--- Grammar: `public [ mut ] <identifier> [ = <expression> ]`
---
--- Identical to `private` except for the visibility it records; codegen lowers a
--- `public` binding to a Lua global rather than a `local`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding         = require("frontend.parser.statements.binding")

return StatementParser.new("PUBLIC", function(parser)
    local mutable = parser:_match("MUTABLE")
    return binding.read_binding(parser, "public", mutable,
        "Expected variable name after 'public'")
end)
