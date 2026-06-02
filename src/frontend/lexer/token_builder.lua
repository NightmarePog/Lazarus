local Token = require("frontend.lexer.token")

---@class PendingToken
---@field type    TokenType
---@field value   string
---@field literal any
---@field line    integer
---@field col     integer

---@class TokenBuilder
local TokenBuilder = {}

---@param type  TokenType
---@param value string
---@return PendingToken
function TokenBuilder.make(type, value)
    return { type = type, value = value, literal = value, line = 0, col = 0 }
end

---@param token PendingToken
---@param line  integer
---@param col   integer
---@return Token
function TokenBuilder.with_position(token, line, col)
    return Token.new(token.type, token.value, line, col, token.literal)
end

---@param value string
---@param line  integer
---@param col   integer
---@return Token
function TokenBuilder.number(value, line, col)
    return Token.new("NUMBER", value, line, col, tonumber(value))
end

---@param type  TokenType
---@param value string
---@param line  integer
---@param col   integer
---@return Token
function TokenBuilder.identifier(type, value, line, col)
    return Token.new(type, value, line, col, value)
end

return TokenBuilder
