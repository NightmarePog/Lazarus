--- Statement handler for `return` statements.
---
--- Grammar: `return [ <expression> ]`
---
--- The expression is optional: a bare `return` (immediately followed by `}` or
--- end of input) produces a `ReturnStmt` with `value = nil`. Whether `return`
--- is legal at this position (inside a function, last in its block) is enforced
--- later by the semantic checker, not here.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ReturnStmt      = require("frontend.parser.nodes.return")

return StatementParser.new("RETURN", function(parser)
    local keyword = parser:_previous() --[[@as Token]]

    local value = nil
    if not (parser:_check("BODY_END") or parser:_is_eof()) then
        value = parser:_expression()
    end

    return ReturnStmt.new(value, keyword.line, keyword.column)
end)
