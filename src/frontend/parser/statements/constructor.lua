--- Statement handler for a class constructor.
---
--- Grammar: `constructor ( [ <param> { , <param> } ] ) { <statement>* }`
---
--- Like a function but with no name and no return — it implicitly returns the new
--- instance. The language is untyped, so parameters carry no annotations. The
--- keyword is consumed by the dispatcher before this runs.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ConstructorDecl = require("frontend.parser.nodes.constructor")

return StatementParser.new("CONSTRUCTOR", function(parser)
    -- The dispatcher consumes the `constructor` keyword before this runs, so
    -- `_previous()` is guaranteed to return it (never nil) at this point.
    local keyword = assert(parser:_previous())

    parser:_consume("LEFT_BRACKET", "Expected '(' after 'constructor'")

    ---@type string[]
    local params = {}
    if not parser:_check("RIGHT_BRACKET") then
        repeat
            local param = parser:_consume("IDENTIFIER", "Expected parameter name")
            params[#params + 1] = param.value
        until not parser:_match("COMMA")
    end

    parser:_consume("RIGHT_BRACKET", "Expected ')' after parameters")

    local body = parser:_block("constructor body")

    return ConstructorDecl.new(params, body, keyword.line, keyword.column)
end)
