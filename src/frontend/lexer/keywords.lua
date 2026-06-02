---@alias TokenType
--- | "LET"
--- | "ASSIGN"
--- | "PLUS"
--- | "MINUS"
--- | "IDENTIFIER"
--- | "NUMBER"
--- | "SYMBOL"

---@type table<string, TokenType>
local Keywords = { ["let"] = "LET", ["="] = "ASSIGN", ["+"] = "PLUS", ["-"] = "MINUS" }

-- Freeze the table so no one can modify it at runtime
setmetatable(Keywords, {
    __newindex = function (_, key, _)
        error("Attempt to modify read-only Keywords table: " .. tostring(key))
    end
})

return Keywords
