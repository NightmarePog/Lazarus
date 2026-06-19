--- Statement handler for the C-style `for` loop, written without parentheses:
---   for <init>; <condition>; <step> { body }
---
--- Each clause is optional. `init` and `step` are assignment statements (a fresh
--- binding or a reassignment, including compound `+=`); `condition` is an
--- expression. An empty clause is `nil`, so `for ; ; { ... }` is a valid (and
--- equivalent to `loop`) form.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ForStmt         = require("frontend.parser.nodes.for")
local binding         = require("frontend.parser.statements.binding")

return StatementParser.new("FOR", function(parser)
    local keyword = parser:_previous() --[[@as Token]]

    local init = nil
    if not parser:_check("SEMICOLON") then
        init = binding.read_assignment(parser, "Expected loop variable in for-init")
    end
    parser:_consume("SEMICOLON", "Expected ';' after for-init")

    local condition = nil
    if not parser:_check("SEMICOLON") then
        condition = parser:_expression()
    end
    parser:_consume("SEMICOLON", "Expected ';' after for-condition")

    local step = nil
    if not parser:_check("BODY_START") then
        step = binding.read_assignment(parser, "Expected statement in for-step")
    end

    local body = parser:_block("for body")
    return ForStmt.new(init, condition, step, body, keyword.line, keyword.column)
end)
