--- Statement handler for `let` variable declarations.
---
--- Grammar: `let <identifier> [ = <expression> ]`
---
--- The `=` and initialiser are optional; omitting them produces a `VariableDecl`
--- with `value = nil`.

local StatementParser = require("src.frontend.parser.statements.statement_parser")
local VariableDecl    = require("src.frontend.parser.nodes.variable")

---@type StatementParser
return StatementParser.new("LET", function(parser)
    local name_token = parser:_consume("IDENTIFIER", "Expected variable name after 'let'")

    local value = nil
    if parser:_match("ASSIGN") then
        value = parser:_expression()
    end

    return VariableDecl.new(name_token.value, value)
end)
