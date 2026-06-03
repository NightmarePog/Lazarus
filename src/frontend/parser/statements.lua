local Error = require("error")
local VariableDecl = require("src.frontend.parser.nodes.variable")

return function(Parser)
    function Parser:_statement()
        if self:_match("LET") then
            local name_token = self:_consume("IDENTIFIER", "Expected variable name")

            local value = nil
            if self:_match("ASSIGN") then
                value = self:_expression()
            end

            return VariableDecl.new(name_token.value, value)
        end

        local token = self:_current()

        if not token then
            Error.throw(Error.Type.UNEXPECTED_EOF, "Unexpected EOF in statement")
        end

        if token.type ~= "NUMBER" and token.type ~= "STRING"
            and token.type ~= "IDENTIFIER" and token.type ~= "LPAREN" then
            Error.throw(Error.Type.UNEXPECTED_TOKEN, "Unexpected token in statement: " .. token.type)
        end

        return { type = "ExpressionStmt", expression = self:_expression() }
    end
end
