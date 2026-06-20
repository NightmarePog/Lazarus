--- Statement handler for a bare `static` method (no visibility modifier).
---
--- Grammar: `static <identifier> ( [params] ) [: T] { body }`
---
--- A `static` method belongs to the class itself (no implicit `self`). A
--- visibility-prefixed form (`public static …`) is handled by the `private`/
--- `public` handlers; this covers the bare form, which defaults to private.

local StatementParser = require("frontend.parser.statements.statement_parser")
local Method = require("frontend.parser.statements.method")

return StatementParser.new("STATIC", function(parser) return Method.parse(parser, nil, true) end)
