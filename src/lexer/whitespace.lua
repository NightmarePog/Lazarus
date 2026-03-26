local lpeg = require("lpeglabel")
local S = lpeg.S

local M = {}

-- spaces, tabs, newlines
M.space = S(" \t") ^ 0
M.newline = S("\n\r") ^ 1

return M
