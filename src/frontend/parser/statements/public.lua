--- Statement handler for `public` declarations.
---
--- Grammar:
---   `public [ mut ] <identifier> [ = <expression> ]`   — an exported binding
---   `public static <identifier> ( … ) { … }`           — an exported static method
---   `public <identifier> ( … ) { … }`                  — an exported instance method
---
--- Identical to `private` except for the visibility it records (`public` marks
--- a member as exported — a Phase 6 concern).

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding         = require("frontend.parser.statements.binding")
local Method          = require("frontend.parser.statements.method")

return StatementParser.new("PUBLIC", function(parser)
    if parser:_match("STATIC") then
        return Method.parse(parser, "public", true)
    end
    if parser:_check("IDENTIFIER") and Method.looks_like_decl(parser) then
        return Method.parse(parser, "public", false)
    end
    local mutable = parser:_match("MUTABLE")
    return binding.read_binding(parser, "public", mutable,
        "Expected variable name after 'public'")
end)
