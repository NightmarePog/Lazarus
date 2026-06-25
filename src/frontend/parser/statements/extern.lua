--- Statement handler for `extern` — binds a namespace member to a raw Lua name.
---
--- Grammar: `extern <name> ( [ <param> { , <param> } ] ) = <string>`
---
--- Example: `extern sub(s, i, j) = "string.sub"`, called as `Sys.sub(...)` from a
--- file that `import`s the namespace. Parameters are documentation only — extern
--- calls are not arity-checked (so variadic Lua targets like `string.format` work)
--- and forward whatever arguments the call site passes. The `extern` keyword is
--- consumed by the dispatcher before this runs.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ExternDecl = require("frontend.parser.nodes.extern")

return StatementParser.new("EXTERN", function(parser)
    local keyword = assert(parser:_previous())

    local name = parser:_consume("IDENTIFIER", "Expected a name after 'extern'")

    parser:_consume("LEFT_BRACKET", "Expected '(' after extern name")

    ---@type string[]
    local params = {}
    if not parser:_check("RIGHT_BRACKET") then
        repeat
            local param = parser:_consume("IDENTIFIER", "Expected parameter name")
            params[#params + 1] = param.value
        until not parser:_match("COMMA")
    end

    parser:_consume("RIGHT_BRACKET", "Expected ')' after extern parameters")
    parser:_consume("ASSIGN", "Expected '=' after extern parameters")
    local target = parser:_consume("STRING", "Expected a quoted Lua target after '='")

    return ExternDecl.new(name.value, params, target.literal --[[@as string]], keyword.line, keyword.column)
end)
