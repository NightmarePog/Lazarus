local Error = require("error")

local AST = require("src.frontend.parser.ast")

---@class Parser
---@field pos         integer
---@field token_table Token[]
---@field _statement  fun(self: Parser): Stmt
---@field _expression fun(self: Parser): Expr
---@field _binary     fun(self: Parser): Expr
---@field _primary    fun(self: Parser): Expr
local Parser = {}
Parser.__index = Parser

---@param token_table Token[]
function Parser.new(token_table)
    return setmetatable({
        pos = 1,
        token_table = token_table
    }, Parser)
end

---@return Token?
function Parser:_current()
    return self.token_table[self.pos]
end

---@param offset? integer
---@return Token?
function Parser:_peek(offset)
    offset = offset or 1
    return self.token_table[self.pos + offset]
end

---@return Token
function Parser:_advance()
    local token = self.token_table[self.pos]

    if not token then
        Error.throw(Error.Type.UNEXPECTED_EOF, "unexpected EOF")
    end
    ---@type Token
    token = token
    self.pos = self.pos + 1
    return token
end

---@return Token?
function Parser:_previous()
    return self.token_table[self.pos - 1]
end

---@param type string
---@return boolean
function Parser:_check(type)
    local token = self:_current()
    return token ~= nil and token.type == type
end

---@vararg string
---@return boolean
function Parser:_match(...)
    local types = { ... }

    for _, t in ipairs(types) do
        if self:_check(t) then
            self:_advance()
            return true
        end
    end

    return false
end

---@param type    string
---@param message string
---@return Token
function Parser:_consume(type, message)
    local token = self:_current()

    if not (token and token.type == type) then
        Error.throw(Error.Type.SYNTAX_ERROR, message .. " at position " .. self.pos)
    end
    return self:_advance()
end

---@return boolean
function Parser:_is_eof()
    return self:_current() == nil
end

---@return AST
function Parser:parse()
    local nodes = {}

    while not self:_is_eof() do
        table.insert(nodes, self:_statement())
    end

    return AST.new(nodes)
end

require("src.frontend.parser.statements")(Parser)
require("src.frontend.parser.expressions")(Parser)

return Parser
