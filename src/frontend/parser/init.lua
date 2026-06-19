--- Recursive-descent parser: consumes a flat token list and produces an AST.
---
--- Statement and expression parsing is split into separate modules
--- (`statements/` and `expressions.lua`) that extend this class by calling
--- the returned function with the `Parser` table.

local Error = require("error")
local AST   = require("frontend.parser.ast")

---@class Parser
---@field pos             integer      Current position in `token_table` (1-based)
---@field token_table     Token[]      Flat list of tokens from the lexer
---@field source          string | nil Original source text, forwarded to errors for snippets
---@field _statement      fun(self: Parser): Stmt
---@field _block          fun(self: Parser, context: string): Stmt[]
---@field _expression     fun(self: Parser): Expr
---@field _binary         fun(self: Parser, min_prec: integer): Expr
---@field _unary          fun(self: Parser): Expr
---@field _call           fun(self: Parser): Expr
---@field _primary        fun(self: Parser): Expr
local Parser = {}
Parser.__index = Parser

--- Create a new parser over `token_table`.
--- Pass `source` to enable source-snippet display in error messages.
---@param token_table Token[]
---@param source?     string
---@return Parser
function Parser.new(token_table, source)
    return setmetatable({
        pos         = 1,
        token_table = token_table,
        source      = source,
    }, Parser)
end

--- Return the token at the current position without consuming it.
---@return Token?
function Parser:_current()
    return self.token_table[self.pos]
end

--- Consume and return the current token, advancing the position.
--- Throws `UNEXPECTED_EOF` if already at the end of the stream.
---@return Token
function Parser:_advance()
    local token = self.token_table[self.pos]

    if not token then
        local prev = self:_previous()
        Error.throw(Error.Type.UNEXPECTED_EOF, "Unexpected end of input",
            (prev and prev.line)   --[[@as integer|nil]],
            (prev and prev.column) --[[@as integer|nil]],
            self.source)
    end

    self.pos = self.pos + 1
    return token --[[@as Token]]
end

--- Return the most recently consumed token (one position behind current).
---@return Token?
function Parser:_previous()
    return self.token_table[self.pos - 1]
end

--- Return `true` if the current token has the given type (without consuming).
---@param tok_type string
---@return boolean
function Parser:_check(tok_type)
    local token = self:_current()
    return token ~= nil and token.type == tok_type
end

--- If the current token matches any of the given types, consume it and
--- return `true`; otherwise leave the position unchanged and return `false`.
---@param ... string
---@return boolean
function Parser:_match(...)
    for i = 1, select("#", ...) do
        if self:_check(select(i, ...) --[[@as string]]) then
            self:_advance()
            return true
        end
    end

    return false
end

--- Consume the current token if it has the expected type.
--- Throws `SYNTAX_ERROR` with `message` and the token's source position otherwise.
---@param tok_type string
---@param message  string
---@return Token
function Parser:_consume(tok_type, message)
    local token = self:_current()

    if not (token and token.type == tok_type) then
        local t = token or self:_previous()
        Error.throw(Error.Type.SYNTAX_ERROR, message,
            (t and t.line)    --[[@as integer|nil]],
            (t and t.column)  --[[@as integer|nil]],
            self.source,
            (t and t.value and #t.value)  --[[@as integer|nil]])
    end

    return self:_advance()
end

--- Return `true` when all tokens have been consumed.
---@return boolean
function Parser:_is_eof()
    return self:_current() == nil
end

--- Parse the full token stream and return the root `AST` (Program) node.
---@return AST
function Parser:parse()
    local nodes = {}

    while not self:_is_eof() do
        table.insert(nodes, self:_statement())
    end

    return AST.new(nodes)
end

local expr_fns = require("frontend.parser.expressions")
local stmt_fns = require("frontend.parser.statements")
for name, fn in pairs(expr_fns) do Parser[name --[[@as string]]] = fn end
for name, fn in pairs(stmt_fns) do Parser[name --[[@as string]]] = fn end

return Parser
