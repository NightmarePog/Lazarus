-- Define the allowed types for a literal
---@alias TokenLiteral string | number | boolean | nil

---@class Token
---@field type    TokenType
---@field value   string
---@field line    integer
---@field column  integer
---@field literal TokenLiteral
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
        type = type,
        value = value,
        line = line,
        column = column,
        literal = literal
    }, Token)
end

---@return string
function Token:__tostring()
    return string.format("Token(%s, %s, %s:%s)", self.type, tostring(self.value), self.line, self.column)
end

return Token
