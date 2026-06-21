--- AST node for a `for-in` loop: `for <var> in <iter> { … }` (iterate a list's
--- values) or `for <k>, <v> in <iter> { … }` (iterate a map's key/value pairs).
---
--- `vars` holds one or two loop-variable names. With one name the loop binds each
--- value; with two it binds the (key/index, value) pair. The iterated value's
--- kind (list vs map) is resolved at runtime by the iteration helper.

---@class ForInStmt: Stmt
---@field type "ForInStmt"
---@field vars string[]      One or two loop-variable names
---@field iter Expr          Expression evaluating to the list/map being iterated
---@field body Stmt[]        Loop body
---@field line integer | nil 1-based source line of `for`
---@field col  integer | nil 1-based source column of `for`
local ForInStmt = {}
ForInStmt.__index = ForInStmt

---@param vars string[]
---@param iter Expr
---@param body Stmt[]
---@param line? integer
---@param col?  integer
---@return ForInStmt
function ForInStmt.new(vars, iter, body, line, col)
    return setmetatable(
        { type = "ForInStmt", vars = vars, iter = iter, body = body, line = line, col = col },
        ForInStmt
    )
end

---@return string
function ForInStmt:__tostring()
    return ("ForInStmt(%s in %s)"):format(table.concat(self.vars, ", "), tostring(self.iter))
end

return ForInStmt
