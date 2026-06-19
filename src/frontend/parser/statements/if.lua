--- Statement handler for `if` / `else if` / `else`.
---
--- Grammar (no parentheses around the condition; braces required):
---   if <expr> { ... } [ else if <expr> { ... } ]* [ else { ... } ]
---
--- Each `if`/`else if` becomes an entry in `clauses`; a trailing `else` (one
--- not followed by `if`) becomes `else_body`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local IfStmt          = require("frontend.parser.nodes.if")

return StatementParser.new("IF", function(parser)
    local keyword = parser:_previous() --[[@as Token]]

    ---@type IfClause[]
    local clauses = { { condition = parser:_expression(), body = parser:_block("if body") } }

    ---@type Stmt[] | nil
    local else_body = nil
    while parser:_match("ELSE") do
        if parser:_match("IF") then
            clauses[#clauses + 1] = {
                condition = parser:_expression(),
                body      = parser:_block("else if body"),
            }
        else
            else_body = parser:_block("else body")
            break
        end
    end

    return IfStmt.new(clauses, else_body, keyword.line, keyword.column)
end)
