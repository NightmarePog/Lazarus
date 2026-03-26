local lpeg = require("lpeglabel")
local R, P, C = lpeg.R, lpeg.P, lpeg.C
local M = {}

local alpha = R("az", "AZ") + P("_")
local alnum = alpha + R("09")

M.IDENT = C(alpha * alnum ^ 0) / function(v)
    return { type = "IDENT", value = v }
end

return M
