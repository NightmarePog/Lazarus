--- Shared binding parser used by every declaration form.
---
--- Grammar (the keyword/`mut` prefix is consumed by the caller before this runs):
---   <identifier> [ "=" <expression> ]
---
--- An immutable binding *must* be initialised — an uninitialised immutable name
--- can never receive a value, so omitting `=` is a syntax error. A `mut` binding
--- may omit the initialiser and be assigned later.

local Error = require("error")
local VariableDecl = require("frontend.parser.nodes.variable")
local BinaryExpr = require("frontend.parser.nodes.binary")
local IdentifierExpr = require("frontend.parser.nodes.identifier")

--- Compound-assignment operators, mapped to the binary operator they expand to.
--- `i += e` desugars to `i = i + e`, so codegen and Schematic see only ordinary
--- reassignment — no node type is needed for compound assignment.
---@type table<string, string>
local COMPOUND = {
    PLUS_ASSIGN = "PLUS",
    MINUS_ASSIGN = "MINUS",
    STAR_ASSIGN = "MULTIPLY",
    SLASH_ASSIGN = "DIVIDE",
}

--- Parse one binding once visibility and mutability are known.
---
--- A visibility binding **without** `static` is an *instance property*: it may be
--- declared type-only (`private x: int`, default `nil`) since the value is set in
--- the constructor. Every other immutable binding must be initialised.
---@param parser      Parser
---@param visibility  "private" | "public" | nil
---@param mutable     boolean
---@param name_err    string  Message for a missing identifier
---@param is_static?  boolean `static` modifier — a class-level member, not a property
---@return VariableDecl
local function read_binding(parser, visibility, mutable, name_err, is_static)
    local name_token = parser:_consume("IDENTIFIER", name_err)

    local value = nil
    if parser:_match("ASSIGN") then value = parser:_expression() end

    -- An instance property (a non-static visibility binding) may omit its
    -- initialiser and default to `nil`. Everything else immutable must be set.
    local is_property = visibility ~= nil and not is_static
    if value == nil and not mutable and not is_property then
        Error.throw(
            Error.Type.SYNTAX_ERROR,
            "Immutable binding '" .. name_token.value .. "' must be initialised: expected '='",
            name_token.line,
            name_token.column,
            parser.source,
            #name_token.value
        )
    end

    return VariableDecl.new(
        name_token.value,
        value,
        visibility,
        mutable,
        name_token.line,
        name_token.column,
        nil,
        is_static
    )
end

--- Parse a bare assignment statement: `<identifier> = <expr>` or a compound
--- assignment `<identifier> (+= | -= | *=) <expr>`. Compound forms desugar to a
--- plain reassignment with a `BinaryExpr` value. Used for top-level bare
--- bindings/reassignments and for the `init`/`step` clauses of a `for` loop.
---@param parser   Parser
---@param name_err string  Message for a missing identifier
---@return VariableDecl
local function read_assignment(parser, name_err)
    local name_token = parser:_consume("IDENTIFIER", name_err)

    if parser:_match("ASSIGN") then
        local value = parser:_expression()
        return VariableDecl.new(
            name_token.value,
            value,
            nil,
            false,
            name_token.line,
            name_token.column
        )
    end

    local op_token = parser:_current()
    local binop = op_token and COMPOUND[op_token.type]
    if not binop then
        Error.throw(
            Error.Type.SYNTAX_ERROR,
            "Expected '=' or a compound assignment after '" .. name_token.value .. "'",
            name_token.line,
            name_token.column,
            parser.source,
            #name_token.value
        )
    end

    parser:_advance()
    local rhs = parser:_expression()
    local target = IdentifierExpr.new(name_token.value, name_token.line, name_token.column)
    local value =
        BinaryExpr.new(binop --[[@as string]], target, rhs, name_token.line, name_token.column)

    return VariableDecl.new(name_token.value, value, nil, false, name_token.line, name_token.column)
end

return { read_binding = read_binding, read_assignment = read_assignment, COMPOUND = COMPOUND }
