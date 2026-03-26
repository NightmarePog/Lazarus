local lpeg           = require("lpeglabel")
local P, R, S, C, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct

local whitespace     = require("lexer.whitespace")
local keywords       = require("lexer.keywords")
local symbols        = require("lexer.symbols")
local identifier     = require("lexer.identifier")

local M              = {}

local COMMENT        = P("//") * (1 - P("\n")) ^ 0 * (P("\n") ^ -1)

local SPACE          = S(" \t\n") ^ 1

local IGNORE         = SPACE + COMMENT

local NEW            = C(P("new")) / function(v)
    return { type = "NEW", value = v }
end


local LUA_BLOCK =
    P("lua") * S(" \t") ^ 0 * P("{") *
    C((1 - P("}")) ^ 1) * P("}") /
    function(v)
        return { type = "LUA_BLOCK", value = v }
    end

local NUMBER    =
    C(R("09") ^ 1 * (P(".") * R("09") ^ 1) ^ -1) /
    function(v)
        return { type = "NUMBER", value = v }
    end

local TOKEN     =
    NEW
    + LUA_BLOCK
    + keywords.LET
    + keywords.CONST
    + keywords.FUNC
    + keywords.EXTENDS
    + keywords.IMPORT
    + keywords.LUA
    + symbols.COLON
    + symbols.EQ
    + symbols.LBRACE
    + symbols.RBRACE
    + symbols.LPAREN
    + symbols.RPAREN
    + symbols.COMMA
    + NUMBER
    + identifier.IDENT


M.token_pattern = Ct(
    (IGNORE ^ 0 * TOKEN) ^ 0
)

return M
