--- Statement handler for `private` declarations.
---
--- Grammar:
---   `private [ mut ] <identifier> [ = <expression> ]`   — a binding (field)
---   `private static <identifier> ( … ) { … }`           — a static method
---   `private <identifier> ( … ) { … }`                  — an instance method
---
--- Bindings are immutable by default; `mut` opts into reassignability. A method
--- is recognised by the `static` keyword or by `name(` lookahead.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding         = require("frontend.parser.statements.binding")
local Method          = require("frontend.parser.statements.method")

return StatementParser.new("PRIVATE", function(parser)
    if parser:_match("STATIC") then
        return Method.parse(parser, "private", true)
    end
    if parser:_check("IDENTIFIER") and Method.looks_like_decl(parser) then
        return Method.parse(parser, "private", false)
    end
    local mutable = parser:_match("MUTABLE")
    return binding.read_binding(parser, "private", mutable,
        "Expected variable name after 'private'")
end)
