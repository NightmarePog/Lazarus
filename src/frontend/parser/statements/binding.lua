--- Shared binding parser used by every declaration form.
---
--- Grammar (the keyword/`mut` prefix is consumed by the caller before this runs):
---   <identifier> [ "=" <expression> ]
---
--- An immutable binding *must* be initialised — an uninitialised immutable name
--- can never receive a value, so omitting `=` is a syntax error. A `mut` binding
--- may omit the initialiser and be assigned later.

local Error        = require("error")
local VariableDecl = require("frontend.parser.nodes.variable")

--- Parse one binding once visibility and mutability are known.
---@param parser     Parser
---@param visibility "private" | "public" | nil
---@param mutable    boolean
---@param name_err   string  Message for a missing identifier
---@return VariableDecl
local function read_binding(parser, visibility, mutable, name_err)
    local name_token = parser:_consume("IDENTIFIER", name_err)

    local value = nil
    if parser:_match("ASSIGN") then
        value = parser:_expression()
    end

    if value == nil and not mutable then
        Error.throw(Error.Type.SYNTAX_ERROR,
            "Immutable binding '" .. name_token.value .. "' must be initialised: expected '='",
            name_token.line, name_token.column, parser.source, #name_token.value)
    end

    return VariableDecl.new(name_token.value, value, visibility, mutable,
        name_token.line, name_token.column)
end

return { read_binding = read_binding }
