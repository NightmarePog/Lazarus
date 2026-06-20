--- Shared parser for method / function declarations.
---
--- Grammar: `[visibility] [static] <identifier> ( [params] ) [: T] { body }`
---
--- A top-level declaration is a class method — instance (implicit `self`) unless
--- `static`. A declaration nested inside a body is an ordinary `local function`.
--- The visibility/`static` keywords are consumed by the caller; this module
--- parses from the method *name* onward and records `is_static`/`visibility` on
--- the `FunctionDecl`.

local FunctionDecl = require("frontend.parser.nodes.function")
local Types = require("frontend.parser.types")

local Method = {}

--- Lookahead: does the `IDENTIFIER` at the current position begin a method
--- declaration `name(params) {`? True when the next token is `(`, its matching
--- `)` is found, and a `{` immediately follows. This separates a declaration
--- from a call statement `name(args)` (no trailing `{`) or an assignment
--- `name = …`. Lazarus has no bare `{ }` block statement, so the trailing `{`
--- is an unambiguous marker.
---@param parser Parser
---@return boolean
function Method.looks_like_decl(parser)
    local toks = parser.token_table
    local pos = parser.pos

    if not (toks[pos + 1] and toks[pos + 1].type == "LEFT_BRACKET") then return false end

    local depth = 0
    for i = pos + 1, #toks do
        local t = toks[i].type
        if t == "LEFT_BRACKET" then
            depth = depth + 1
        elseif t == "RIGHT_BRACKET" then
            depth = depth - 1
            if depth == 0 then
                local after = toks[i + 1]
                return after ~= nil and after.type == "BODY_START"
            end
        end
    end
    return false
end

--- Parse a method body header and block, the name token still current.
---@param parser     Parser
---@param visibility string | nil   "private" | "public" | nil (defaults to private)
---@param is_static  boolean
---@return FunctionDecl
function Method.parse(parser, visibility, is_static)
    local name_token = parser:_consume("IDENTIFIER", "Expected method name")

    parser:_consume("LEFT_BRACKET", "Expected '(' after method name")

    ---@type string[]
    local params = {}
    ---@type (TypeRef | nil)[]
    local param_types = {}
    if not parser:_check("RIGHT_BRACKET") then
        repeat
            local param = parser:_consume("IDENTIFIER", "Expected parameter name")
            params[#params + 1] = param.value
            param_types[#params] = parser:_match("COLON") and Types.read_type(parser) or nil
        until not parser:_match("COMMA")
    end

    parser:_consume("RIGHT_BRACKET", "Expected ')' after parameters")

    local return_type = parser:_match("COLON") and Types.read_type(parser) or nil

    local body = parser:_block("method body")

    return FunctionDecl.new(
        name_token.value,
        params,
        body,
        name_token.line,
        name_token.column,
        param_types,
        return_type,
        is_static,
        visibility
    )
end

return Method
