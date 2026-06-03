local Error = require("error")
local LiteralExpr = require("src.frontend.parser.nodes.literal")
local IdentifierExpr = require("src.frontend.parser.nodes.identifier")
local BinaryExpr = require("src.frontend.parser.nodes.binary")

return function(Parser)
    function Parser:_expression()
        return self:_binary()
    end

    function Parser:_binary()
        local left = self:_primary()

        while self:_match("PLUS", "MINUS") do
            local op = self:_previous()
            local right = self:_primary()
            left = BinaryExpr.new(op.type, left, right)
        end

        return left
    end

    function Parser:_primary()
        local token = self:_current()

        if not token then
            Error.throw(Error.Type.UNEXPECTED_EOF, "Unexpected EOF in primary")
        end

        if token.type == "NUMBER" then
            self:_advance()
            return LiteralExpr.new(token.literal)
        end

        if token.type == "STRING" then
            self:_advance()
            return LiteralExpr.new(token.value)
        end

        if token.type == "IDENTIFIER" then
            self:_advance()
            return IdentifierExpr.new(token.value)
        end

        Error.throw(Error.Type.UNEXPECTED_TOKEN, "Unexpected token in primary: " .. token.type)
    end
end
