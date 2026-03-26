local lpeg = require("lpeglabel")
local P, C = lpeg.P, lpeg.C
local M = {}

local function sym(type_name, char)
    return C(P(char)) / function(v)
        return { type = type_name, value = v }
    end
end

M.COLON  = sym("COLON", ":")
M.EQ     = sym("EQ", "=")
M.LBRACE = sym("LBRACE", "{")
M.RBRACE = sym("RBRACE", "}")
M.LPAREN = sym("LPAREN", "(")
M.RPAREN = sym("RPAREN", ")")
M.COMMA  = sym("COMMA", ",")

return M
