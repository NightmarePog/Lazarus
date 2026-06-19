--- Statement dispatcher: routes the current token to the appropriate handler.
---
--- To add a new statement type, create a `StatementParser` in its own file
--- and add it to `HANDLERS`.  No other code needs to change.

local Error       = require("error")
local Keywords    = require("frontend.lexer.keywords")
local ExprStmt    = require("frontend.parser.nodes.expression_stmt")
local FieldAssign = require("frontend.parser.nodes.field_assign")
local BinaryExpr  = require("frontend.parser.nodes.binary")
local binding     = require("frontend.parser.statements.binding")

--- All registered statement handlers, keyed by their trigger token type.
--- Add new handlers here — the dispatcher builds the registry automatically.
---@type StatementParser[]
local HANDLERS = {
    (require("frontend.parser.statements.private")),
    (require("frontend.parser.statements.public")),
    (require("frontend.parser.statements.mut")),
    (require("frontend.parser.statements.function")),
    (require("frontend.parser.statements.return")),
    (require("frontend.parser.statements.if")),
    (require("frontend.parser.statements.while")),
    (require("frontend.parser.statements.loop")),
    (require("frontend.parser.statements.for")),
    (require("frontend.parser.statements.break")),
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
    --- keyword-only tokens produce an `UNEXPECTED_TOKEN` error.  Anything else
    --- is treated as an expression statement.
    ---@param self Parser
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

        -- Bare binding / reassignment: `<identifier> = <expr>` or a compound
        -- assignment `<identifier> += <expr>`. The keyword is absent (no
        -- visibility, immutable), so it is recognised by lookahead rather than
        -- by the registry. Schematic resolves declaration vs reassignment by
        -- scope.
        if tok.type == "IDENTIFIER" then
            local nxt = self.token_table[self.pos + 1]
            -- `name =`, `name +=`, … or an annotated declaration `name : Type = …`.
            if nxt and (nxt.type == "ASSIGN" or nxt.type == "COLON" or binding.COMPOUND[nxt.type]) then
                return binding.read_assignment(self, "Expected variable name")
            end
        end

        if Keywords.is_invalid_token_type(tok.type) then
            Error.throw(Error.Type.UNEXPECTED_TOKEN,
                "Unexpected '" .. tok.value .. "' in statement",
                tok.line, tok.column, self.source, #tok.value)
        end

        local expr = self:_expression()

        -- Field assignment: `object.field = value` (or compound `+=`). A bare
        -- name assignment is already handled above by `read_assignment`; here the
        -- only assignable lvalue is a field access.
        if expr.type == "MemberExpr" then
            if self:_match("ASSIGN") then
                local value = self:_expression()
                return FieldAssign.new(expr --[[@as MemberExpr]], value, tok.line, tok.column)
            end
            local op = self:_current()
            local binop = op and binding.COMPOUND[op.type]
            if binop then
                self:_advance()
                local rhs   = self:_expression()
                local value = BinaryExpr.new(binop --[[@as string]], expr, rhs, tok.line, tok.column)
                return FieldAssign.new(expr --[[@as MemberExpr]], value, tok.line, tok.column)
            end
        end

        return ExprStmt.new(expr, tok.line, tok.column)
    end,

    --- Parse a braced block `{ <statement>* }`, returning the statement list.
    --- `context` names the construct for error messages (e.g. "if body").
    ---@param self    Parser
    ---@param context string
    ---@return Stmt[]
    _block = function(self, context)
        local open = self:_consume("BODY_START", "Expected '{' to open " .. context)

        ---@type Stmt[]
        local body = {}
        while not self:_check("BODY_END") do
            if self:_is_eof() then
                Error.throw(Error.Type.SYNTAX_ERROR,
                    "Expected '}' to close " .. context,
                    open.line, open.column, self.source, #open.value)
            end
            body[#body + 1] = self:_statement()
        end

        self:_consume("BODY_END", "Expected '}' to close " .. context)
        return body
    end,
}
