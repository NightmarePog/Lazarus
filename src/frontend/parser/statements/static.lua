--- Statement handler for a bare `static` declaration (no visibility modifier).
---
--- Grammar:
---   `static <identifier> ( [params] ) [: T] { body }`   — a static method
---   `static <identifier> [ = <expression> ]`            — a static member
---
--- A `static` member/method belongs to the class itself (no implicit `self`). A
--- visibility-prefixed form (`public static …`) is handled by the `private`/
--- `public` handlers. A bare static member carries no visibility, which Schematic
--- rejects (top-level members must declare one) — the method form defaults to
--- private.

local StatementParser = require("frontend.parser.statements.statement_parser")
local binding = require("frontend.parser.statements.binding")
local Method = require("frontend.parser.statements.method")

return StatementParser.new("STATIC", function(parser)
    if parser:_check("IDENTIFIER") and Method.looks_like_decl(parser) then
        return Method.parse(parser, nil, true)
    end
    local static_mut = parser:_match("MUTABLE")
    return binding.read_binding(
        parser,
        nil,
        static_mut,
        "Expected member name after 'static'",
        true
    )
end)
