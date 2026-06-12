--- Statement handler for `private` variable declarations.
---
--- Grammar: `private <identifier> [ = <expression> ]`
---
--- The `=` and initialiser are optional; omitting them produces a `VariableDecl`
--- with `value = nil`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local VariableDecl    = require("frontend.parser.nodes.variable")

---@type StatementParser
return StatementParser.new("PRIVATE", function(parser)
    local name_token = parser:_consume("IDENTIFIER", "Expected variable name after 'private'")

    local value = nil
    if parser:_match("ASSIGN") then
        value = parser:_expression()
    end

    return VariableDecl.new(name_token.value, value)
end)
