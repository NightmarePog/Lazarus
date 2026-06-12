--- Statement dispatcher: routes the current token to the appropriate handler.
---
--- To add a new statement type, create a `StatementParser` in its own file
--- and add it to `HANDLERS`.  No other code needs to change.

local Error    = require("error")
local Keywords = require("frontend.lexer.keywords")
local ExprStmt = require("frontend.parser.nodes.expression_stmt")

--- All registered statement handlers, keyed by their trigger token type.
--- Add new handlers here — the dispatcher builds the registry automatically.
---@type StatementParser[]
local HANDLERS = {
    (require("frontend.parser.statements.let")),
}

---@type table<string, StatementParser?>
local registry = {}
for _, handler in ipairs(HANDLERS) do
    registry[handler.keyword] = handler
end

return {
    --- Parse one statement.
    ---
    --- If the current token matches a registered keyword the corresponding
    --- handler is called (with the keyword already consumed).  Unrecognised
    --- keyword-only tokens produce a `SYNTAX_ERROR`.  Anything else is
    --- treated as an expression statement.
    ---@return Stmt
    _statement = function(self)
        local token = self:_current()

        if not token then
            local prev = self:_previous()
            Error.throw(Error.Type.UNEXPECTED_EOF, "Unexpected end of input",
                (prev and prev.line)   --[[@as integer|nil]],
                (prev and prev.column) --[[@as integer|nil]],
                self.source)
        end

        local tok = token --[[@as Token]]

        local handler = registry[tok.type]
        if handler then
            self:_advance()
            return handler.parse(self)
        end

        if Keywords.is_invalid_token_type(tok.type) then
            Error.throw(Error.Type.UNEXPECTED_TOKEN,
                "Unexpected '" .. tok.value .. "' in statement",
                tok.line, tok.column, self.source, #tok.value)
        end

        return ExprStmt.new(self:_expression())
    end,
}
