--- Statement handler for a class constructor.
---
--- Grammar: `constructor ( [ <param> [: Type] { , <param> [: Type] } ] ) { <statement>* }`
---
--- Like a function but with no name and no return type — it implicitly returns
--- the new instance. The keyword is consumed by the dispatcher before this runs.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ConstructorDecl = require("frontend.parser.nodes.constructor")
local Types           = require("frontend.parser.types")

return StatementParser.new("CONSTRUCTOR", function(parser)
    local keyword = parser:_previous()

    parser:_consume("LEFT_BRACKET", "Expected '(' after 'constructor'")

    ---@type string[]
    local params = {}
    ---@type (TypeRef | nil)[]
    local param_types = {}
    if not parser:_check("RIGHT_BRACKET") then
        repeat
            local param = parser:_consume("IDENTIFIER", "Expected parameter name")
            params[#params + 1] = param.value
            param_types[#params] = parser:_match("COLON") and Types.read_type(parser) or nil
        until not parser:_match("COMMA")
    end

    parser:_consume("RIGHT_BRACKET", "Expected ')' after parameters")

    local body = parser:_block("constructor body")

    return ConstructorDecl.new(params, body, keyword.line, keyword.column, param_types)
end)
