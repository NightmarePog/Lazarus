--- Statement handler for `constant` declarations.
---
--- Grammar: `constant <identifier> = <expression>`
---
--- The `=` and initialiser are required; omitting them is a syntax error.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ConstantDecl    = require("frontend.parser.nodes.constant")
local Error           = require("error")

return StatementParser.new("CONSTANT", function(parser)
    local name_token = parser:_consume("IDENTIFIER", "Expected constant name after 'constant'")

    if not parser:_match("ASSIGN") then
        Error.throw(Error.Type.SYNTAX_ERROR,
            "Constants must be initialised: expected '=' after '" .. name_token.value .. "'",
            name_token.line, name_token.column, parser.source, #name_token.value)
    end

    local value = parser:_expression()
    return ConstantDecl.new(name_token.value, value, name_token.line, name_token.column)
end)
