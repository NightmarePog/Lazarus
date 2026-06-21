--- Statement handler for `private` declarations.
---
--- Grammar:
---   `private [ mut ] <identifier> [ = <expression> ]`   — an instance property
---   `private static <identifier> [ = <expression> ]`    — a class-level member
---   `private static <identifier> ( … ) { … }`           — a static method
---   `private <identifier> ( … ) { … }`                  — an instance method
---
--- A binding without `static` is an instance property (it may be type-only).
--- `static` marks a class-level member (or, with `name(`, a static method). A
--- method is recognised by `name(` lookahead.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding = require("frontend.parser.statements.binding")
local Method = require("frontend.parser.statements.method")

return StatementParser.new("PRIVATE", function(parser)
    if parser:_match("STATIC") then
        if parser:_check("IDENTIFIER") and Method.looks_like_decl(parser) then
            return Method.parse(parser, "private", true)
        end
        local static_mut = parser:_match("MUTABLE")
        return binding.read_binding(
            parser,
            "private",
            static_mut,
            "Expected member name after 'private static'",
            true
        )
    end
    if parser:_check("IDENTIFIER") and Method.looks_like_decl(parser) then
        return Method.parse(parser, "private", false)
    end
    local mutable = parser:_match("MUTABLE")
    return binding.read_binding(
        parser,
        "private",
        mutable,
        "Expected property name after 'private'"
    )
end)
