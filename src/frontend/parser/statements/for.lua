--- Statement handler for the two `for` forms:
---   • C-style: `for <init>; <condition>; <step> { body }`
---   • for-in:  `for <var> in <iter> { body }`  /  `for <k>, <v> in <iter> { body }`
---
--- They are distinguished by lookahead: a `for` whose first token is an
--- identifier followed by `in` or `,` is a for-in loop (iterate a list's values
--- or a map's key/value pairs); anything else is the C-style loop.
---
--- C-style: each clause is optional. `init` and `step` are assignment statements
--- (a fresh binding or a reassignment, including compound `+=`); `condition` is
--- an expression. An empty clause is `nil`, so `for ; ; { ... }` is valid.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ForStmt         = require("frontend.parser.nodes.for")
local ForInStmt       = require("frontend.parser.nodes.for_in")
local binding         = require("frontend.parser.statements.binding")

--- True when the upcoming tokens are `<ident> in` or `<ident> , <ident> in`.
---@param parser Parser
---@return boolean
local function looks_like_for_in(parser)
    if not parser:_check("IDENTIFIER") then return false end
    local nxt = parser.token_table[parser.pos + 1]
    if not nxt then return false end
    if nxt.type == "IN" then return true end
    -- `for k, v in …`: identifier, comma, identifier, `in`.
    return nxt.type == "COMMA"
end

return StatementParser.new("FOR", function(parser)
    local keyword = parser:_previous() --[[@as Token]]

    if looks_like_for_in(parser) then
        ---@type string[]
        local vars = { (parser:_consume("IDENTIFIER", "Expected a loop variable after 'for'")).value }
        if parser:_match("COMMA") then
            vars[#vars + 1] =
                (parser:_consume("IDENTIFIER", "Expected a second loop variable after ','")).value
        end
        parser:_consume("IN", "Expected 'in' after the for-in loop variable(s)")
        local iter = parser:_expression()
        local body = parser:_block("for body")
        return ForInStmt.new(vars, iter, body, keyword.line, keyword.column)
    end

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
