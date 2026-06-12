--- Token produced by the lexer.
---
--- Every token carries both the raw source text (`value`) and an optional
--- pre-converted value (`literal`, e.g. a Lua number for `NUMBER` tokens).
--- Downstream code should use `literal` for semantic purposes and `value`
--- only when reproducing the original source text.

--- Allowed concrete types for a token's converted literal value.
---@alias TokenLiteral string | number | boolean | nil

---@class Token
---@field type    TokenType    Symbolic type constant (e.g. `"NUMBER"`, `"LET"`)
---@field value   string       Raw source text of the token
---@field line    integer      1-based source line
---@field column  integer      1-based source column
---@field literal TokenLiteral Converted value (e.g. a Lua `number` for `NUMBER` tokens)
local Token = {}
Token.__index = Token

---@param type     TokenType
---@param value    string
---@param line     integer
---@param column   integer
---@param literal? TokenLiteral
---@return Token
function Token.new(type, value, line, column, literal)
    return setmetatable({
        type    = type,
        value   = value,
        line    = line,
        column  = column,
        literal = literal,
    }, Token)
end

---@return string
function Token:__tostring()
    return string.format("Token(%s, %s, %s:%s)", self.type, tostring(self.value), self.line, self.column)
end

return Token
