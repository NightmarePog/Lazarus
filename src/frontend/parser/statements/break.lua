--- Statement handler for `break` — exits the nearest enclosing loop. Whether it
--- is legally placed (inside a loop, last in its block) is enforced by Schematic.

local StatementParser = require("frontend.parser.statements.statement_parser")
local BreakStmt       = require("frontend.parser.nodes.break")

return StatementParser.new("BREAK", function(parser)
    local keyword = parser:_previous() --[[@as Token]]
    return BreakStmt.new(keyword.line, keyword.column)
end)
