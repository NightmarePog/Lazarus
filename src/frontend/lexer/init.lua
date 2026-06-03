local Error = require("error")
local Keywords = require("frontend.lexer.keywords")
local Token = require("frontend.lexer.token")

---@class Lexer
---@field source  string
---@field pos     integer
---@field line    integer
---@field col     integer
---@field current string
local Lexer = {}
Lexer.__index = Lexer

---@param source string
---@return Lexer
function Lexer.new(source)
    return setmetatable({
        source = source,
        pos = 1,
        line = 1,
        col = 1,
        current = source:sub(1, 1)
    }, Lexer)
end

---@private
function Lexer:_advance()
    if self.current == "\n" then
        self.line = self.line + 1
        self.col = 1
    else
        self.col = self.col + 1
    end

    self.pos = self.pos + 1
    self.current = self.pos <= #self.source and self.source:sub(self.pos, self.pos) or ""
end

---@return Token
---@private
function Lexer:_read_identifier()
    local start = self.pos
    local line, col = self.line, self.col

    while self.current ~= "" and (self.current:match("[%a_]") or self.current:match("%d")) do
        self:_advance()
    end

    local value = self.source:sub(start, self.pos - 1)
    local type = Keywords[value] or "IDENTIFIER"

    return Token.new(type, value, line, col, value)
end

---@return Token
---@private
function Lexer:_read_number()
    local start = self.pos
    local line, col = self.line, self.col

    while self.current ~= "" and self.current:match("%d") do
        self:_advance()
    end

    local raw = self.source:sub(start, self.pos - 1)
    return Token.new("NUMBER", raw, line, col, tonumber(raw))
end

---@return Token
---@private
function Lexer:_read_symbol()
    local line, col = self.line, self.col
    local char = self.current

    self:_advance()

    local type = Keywords[char]
    if not type then
        Error.throw(Error.Type.UNEXPECTED_CHAR, "Unexpected character: " .. char)
    end

    return Token.new(type, char, line, col, char)
end

---@return Token?
---@private
function Lexer:_next_token()
    while self.current ~= "" and self.current:match("%s") do
        self:_advance()
    end

    if self.current == "" then return nil end

    if self.current:match("[%a_]") then return self:_read_identifier() end
    if self.current:match("%d") then return self:_read_number() end

    return self:_read_symbol()
end

---@return Token[]
function Lexer:scan()
    local tokens = {}
    while true do
        local token = self:_next_token()
        if not token then break end
        table.insert(tokens, token)
    end
    return tokens
end

return Lexer
