--- Source-text lexer: scans a raw string and produces a flat `Token[]`.
---
--- The lexer is a simple single-pass scanner.  It records `line` and `column`
--- for every token so that the parser can attach accurate source positions to
--- any errors it raises.

local Error    = require("error")
local Keywords = require("src.frontend.lexer.keywords")
local Token    = require("src.frontend.lexer.token")

---@class Lexer
---@field source  string  Original source text
---@field pos     integer Current byte position (1-based)
---@field line    integer Current line number (1-based)
---@field col     integer Current column number (1-based)
---@field current string  Character at `pos`, or `""` at EOF
local Lexer = {}
Lexer.__index = Lexer

---@param source string
---@return Lexer
function Lexer.new(source)
    return setmetatable({
        source  = source,
        pos     = 1,
        line    = 1,
        col     = 1,
        current = source:sub(1, 1),
    }, Lexer)
end

--- Advance one character, updating `line` and `col`.
---@private
function Lexer:_advance()
    if self.current == "\n" then
        self.line = self.line + 1
        self.col  = 1
    else
        self.col = self.col + 1
    end

    self.pos     = self.pos + 1
    self.current = self.pos <= #self.source and self.source:sub(self.pos, self.pos) or ""
end

--- Scan a keyword or identifier starting at the current position.
---@private
---@return Token
function Lexer:_read_identifier()
    local start     = self.pos
    local line, col = self.line, self.col

    while self.current ~= "" and self.current:match("[%a_%d]") do
        self:_advance()
    end

    local value    = self.source:sub(start, self.pos - 1)
    local tok_type = (Keywords.TOKENS[value] or "IDENTIFIER") --[[@as TokenType]]

    return Token.new(tok_type, value, line, col, value)
end

--- Scan a decimal integer literal starting at the current position.
---@private
---@return Token
function Lexer:_read_number()
    local start     = self.pos
    local line, col = self.line, self.col

    while self.current ~= "" and self.current:match("%d") do
        self:_advance()
    end

    local raw = self.source:sub(start, self.pos - 1)
    return Token.new("NUMBER", raw, line, col, tonumber(raw))
end

--- Scan a single-character symbol (operator or punctuation).
--- Throws `UNEXPECTED_CHAR` for characters not in the keyword table.
---@private
---@return Token
function Lexer:_read_symbol()
    local line, col = self.line, self.col
    local char      = self.current

    self:_advance()

    local tok_type = Keywords.TOKENS[char]
    if not tok_type then
        Error.throw(Error.Type.UNEXPECTED_CHAR,
            "Unexpected character '" .. char .. "'",
            line, col, self.source, 1)
    end

    return Token.new(tok_type --[[@as TokenType]], char, line, col, char)
end

--- Return the next non-whitespace token, or `nil` at EOF.
---@private
---@return Token?
function Lexer:_next_token()
    while self.current ~= "" and self.current:match("%s") do
        self:_advance()
    end

    if self.current == "" then return nil end

    if self.current:match("[%a_]") then return self:_read_identifier() end
    if self.current:match("%d")    then return self:_read_number()     end

    return self:_read_symbol()
end

--- Scan the full source and return all tokens as a flat list.
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
