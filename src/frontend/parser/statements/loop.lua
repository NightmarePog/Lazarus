--- Statement handler for `loop { body }` — an explicit infinite loop.

local StatementParser = require("frontend.parser.statements.statement_parser")
local LoopStmt        = require("frontend.parser.nodes.loop")

return StatementParser.new("LOOP", function(parser)
    local keyword = parser:_previous() --[[@as Token]]
    local body    = parser:_block("loop body")
    return LoopStmt.new(body, keyword.line, keyword.column)
end)
