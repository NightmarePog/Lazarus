--- Statement handler for `while <condition> { body }` (no parentheses).

local StatementParser = require("frontend.parser.statements.statement_parser")
local WhileStmt       = require("frontend.parser.nodes.while")

return StatementParser.new("WHILE", function(parser)
    local keyword   = parser:_previous() --[[@as Token]]
    local condition = parser:_expression()
    local body      = parser:_block("while body")
    return WhileStmt.new(condition, body, keyword.line, keyword.column)
end)
