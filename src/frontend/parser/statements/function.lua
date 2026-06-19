--- Statement handler for function declarations.
---
--- Grammar: `fn <identifier> ( [ <identifier> { , <identifier> } ] ) { <statement>* }`
---
--- Parameters are a comma-separated list of identifiers (possibly empty). The
--- body is a sequence of statements parsed by the shared dispatcher until the
--- closing `}`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local FunctionDecl    = require("frontend.parser.nodes.function")

return StatementParser.new("FUNCTION", function(parser)
    local name_token = parser:_consume("IDENTIFIER", "Expected function name after 'fn'")

    parser:_consume("LEFT_BRACKET", "Expected '(' after function name")

    ---@type string[]
    local params = {}
    if not parser:_check("RIGHT_BRACKET") then
        repeat
            local param = parser:_consume("IDENTIFIER", "Expected parameter name")
            params[#params + 1] = param.value
        until not parser:_match("COMMA")
    end

    parser:_consume("RIGHT_BRACKET", "Expected ')' after parameters")

    local body = parser:_block("function body")

    return FunctionDecl.new(name_token.value, params, body, name_token.line, name_token.column)
end)
