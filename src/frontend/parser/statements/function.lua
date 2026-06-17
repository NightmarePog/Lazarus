--- Statement handler for function declarations.
---
--- Grammar: `fn <identifier> ( [ <identifier> { , <identifier> } ] ) { <statement>* }`
---
--- Parameters are a comma-separated list of identifiers (possibly empty). The
--- body is a sequence of statements parsed by the shared dispatcher until the
--- closing `}`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local FunctionDecl    = require("frontend.parser.nodes.function")
local Error           = require("error")

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
    parser:_consume("BODY_START", "Expected '{' to open function body")

    ---@type Stmt[]
    local body = {}
    while not parser:_check("BODY_END") do
        if parser:_is_eof() then
            Error.throw(Error.Type.SYNTAX_ERROR,
                "Expected '}' to close function body",
                name_token.line, name_token.column, parser.source, #name_token.value)
        end
        body[#body + 1] = parser:_statement()
    end

    parser:_consume("BODY_END", "Expected '}' to close function body")

    return FunctionDecl.new(name_token.value, params, body, name_token.line, name_token.column)
end)
