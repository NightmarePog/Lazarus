--- Test-only helpers for building `Token` values without running the lexer.
---
--- `PendingToken` is an intermediate form with zero-position that can be
--- promoted to a real `Token` via `with_position`.

local Token = require("frontend.lexer.token")

---@class PendingToken
---@field type    TokenType
---@field value   string
---@field literal any
---@field line    integer
---@field column  integer

---@class TokenBuilder
local TokenBuilder = {}

--- Create a zero-position pending token with the given type and value.
---@param tok_type TokenType
---@param value    string
---@return PendingToken
function TokenBuilder.make(tok_type, value)
    return { type = tok_type, value = value, literal = value, line = 0, column = 0 } --[[@as PendingToken]]
end

--- Promote a `PendingToken` to a positioned `Token`.
---@param token PendingToken
---@param line  integer
---@param col   integer
---@return Token
function TokenBuilder.with_position(token, line, col)
    return Token.new(token.type, token.value, line, col, token.literal)
end

--- Construct a NUMBER token, converting `value` to a Lua number for `literal`.
---@param value string
---@param line  integer
---@param col   integer
---@return Token
function TokenBuilder.number(value, line, col)
    return Token.new("NUMBER", value, line, col, tonumber(value))
end

--- Construct a keyword or identifier token.
---@param tok_type TokenType
---@param value    string
---@param line     integer
---@param col      integer
---@return Token
function TokenBuilder.identifier(tok_type, value, line, col)
    return Token.new(tok_type, value, line, col, value)
end

return TokenBuilder
