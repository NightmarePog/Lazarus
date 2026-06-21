--- Primary expressions: the atoms of the grammar — literals, identifiers, and
--- parenthesised sub-expressions. This is the tightest-binding level.

local Error = require("error")
local LiteralExpr = require("frontend.parser.nodes.literal")
local IdentifierExpr = require("frontend.parser.nodes.identifier")
local MemberExpr = require("frontend.parser.nodes.member")
local SelfExpr = require("frontend.parser.nodes.self")
local ListExpr = require("frontend.parser.nodes.list")
local MapExpr = require("frontend.parser.nodes.map")

--- Parse a list or map literal once the opening `[` is current.
---
--- Disambiguated by content: `[]` is an empty list, `[:]` an empty map, and a
--- non-empty literal is a map when its first element is followed by `:` (a
--- `key: value` pair), otherwise a list.
---@param self Parser
---@return Expr
local function _collection(self)
    local open = self:_advance() --[[@as Token]] -- consume '['

    -- Empty forms: `[]` (list) and `[:]` (map).
    if self:_check("RSQUARE") then
        self:_advance()
        return ListExpr.new({}, open.line, open.column)
    end
    if self:_check("COLON") then
        self:_advance()
        self:_consume("RSQUARE", "Expected ']' to close empty map '[:]'")
        return MapExpr.new({}, open.line, open.column)
    end

    local first = self:_expression()

    -- A `:` after the first element makes this a map literal.
    if self:_match("COLON") then
        local value = self:_expression()
        ---@type MapEntry[]
        local entries = { { key = first, value = value } }
        while self:_match("COMMA") do
            local k = self:_expression()
            self:_consume("COLON", "Expected ':' between a map key and its value")
            local v = self:_expression()
            entries[#entries + 1] = { key = k, value = v }
        end
        self:_consume("RSQUARE", "Expected ']' to close the map literal")
        return MapExpr.new(entries, open.line, open.column)
    end

    -- Otherwise a list literal.
    local elements = { first }
    while self:_match("COMMA") do
        elements[#elements + 1] = self:_expression()
    end
    self:_consume("RSQUARE", "Expected ']' to close the list literal")
    return ListExpr.new(elements, open.line, open.column)
end

return {
    ---@param self Parser
    ---@return Expr
    _primary = function(self)
        local token = self:_current()

        if not token then
            local prev = self:_previous()
            Error.throw(
                Error.Type.UNEXPECTED_EOF,
                "Unexpected end of input",
                (prev and prev.line) --[[@as integer|nil]],
                (prev and prev.column) --[[@as integer|nil]],
                self.source
            )
        end

        local tok = token --[[@as Token]]

        if tok.type == "LEFT_BRACKET" then
            self:_advance()
            local expr = self:_expression()
            self:_consume("RIGHT_BRACKET", "Expected ')' after expression")
            return expr
        end

        if tok.type == "NUMBER" then
            self:_advance()
            -- A fractional part in the source text marks the literal as a float.
            local numeric = tok.value:find(".", 1, true) and "float" or "int"
            return LiteralExpr.new("number", tok.literal, tok.line, tok.column, numeric)
        end

        if tok.type == "STRING" then
            self:_advance()
            return LiteralExpr.new("string", tok.literal, tok.line, tok.column)
        end

        if tok.type == "TRUE" or tok.type == "FALSE" then
            self:_advance()
            return LiteralExpr.new("boolean", tok.type == "TRUE", tok.line, tok.column)
        end

        if tok.type == "IDENTIFIER" then
            self:_advance()
            return IdentifierExpr.new(tok.value, tok.line, tok.column)
        end

        -- The receiver value. `self` is a SelfExpr; the postfix parser (`_call`)
        -- turns `self.x` into a MemberExpr over it — the same node a leading-dot
        -- `.x` produces, so `self.x` and `.x` are exactly equivalent.
        if tok.type == "SELF" then
            self:_advance()
            return SelfExpr.new(tok.line, tok.column)
        end

        -- A list (`[…]`) or map (`["k": v]`) literal.
        if tok.type == "LSQUARE" then
            return _collection(self)
        end

        -- Leading dot: instance field of the implicit receiver (`.x`), shorthand
        -- for `self.x`. Lowers to a MemberExpr over a SelfExpr; the postfix parser
        -- (`_call`) handles any further `.y` / `(...)` chain.
        if tok.type == "DOT" then
            self:_advance()
            local field = self:_consume("IDENTIFIER", "Expected a field name after '.'")
            return MemberExpr.new(
                SelfExpr.new(tok.line, tok.column),
                field.value,
                tok.line,
                tok.column
            )
        end

        Error.throw(
            Error.Type.UNEXPECTED_TOKEN,
            "Unexpected token '" .. tok.value .. "'",
            tok.line,
            tok.column,
            self.source,
            #tok.value
        )
        error("unreachable")
    end,
}
