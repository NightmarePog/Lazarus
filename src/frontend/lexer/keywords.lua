local lpeg = require("lpeglabel")
local P, C = lpeg.P, lpeg.C
local M = {}


local function keyword(name)
    return C(P(name) * -lpeg.R("az", "AZ", "09") * -P("_")) / function(v)
        return { type = name:upper(), value = v }
    end
end

M.LET     = keyword("let")
M.CONST   = keyword("const")
M.FUNC    = keyword("func")
M.EXTENDS = keyword("extends")
M.IMPORT  = keyword("import")
M.LUA     = keyword("lua")

return M
