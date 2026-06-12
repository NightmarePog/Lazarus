--- Keyword and operator tables used by the lexer and the statement dispatcher.

local Keywords = {}

---@alias TokenType
--- | "LET"
--- | "ASSIGN"
--- | "PLUS"
--- | "MINUS"
--- | "IDENTIFIER"
--- | "NUMBER"
--- | "SYMBOL"
--- | "MULTIPLY"
--- | "LEFT_BRACKET"
--- | "RIGHT_BRACKET"

--- Maps source-text strings to their `TokenType`.
--- The table is frozen: mutation raises a runtime error.
---@type table<string, TokenType>
local TOKENS = {
    ["let"] = "LET",
    ["="]   = "ASSIGN",
    ["+"]   = "PLUS",
    ["-"]   = "MINUS",
    ["*"]   = "MULTIPLY",
    ["("]   = "LEFT_BRACKET",
    [")"]   = "RIGHT_BRACKET",
}
setmetatable(TOKENS, {
    __newindex = function(_, key)
        error("Attempt to modify read-only Keywords.TOKENS: " .. tostring(key))
    end,
})
Keywords.TOKENS = TOKENS

--- Token types that may appear in expressions or as primary values.
--- Everything NOT in this set is considered an invalid position for an
--- expression-level token (e.g. `LET`, `ASSIGN`).
---@type table<string, boolean>
local VALID_TYPES = { NUMBER = true, IDENTIFIER = true }
for _, token_type in pairs(TOKENS) do
    if token_type ~= "LET" and token_type ~= "ASSIGN" then
        VALID_TYPES[token_type] = true
    end
end

--- Return `true` when `token_type` cannot legally appear in expression
--- position (i.e. it is a keyword-only or assignment-only token).
---@param token_type string
---@return boolean
function Keywords.is_invalid_token_type(token_type)
    return not VALID_TYPES[token_type]
end

setmetatable(Keywords, {
    __index = TOKENS,

    __newindex = function(_, key)
        error("Attempt to modify read-only Keywords table: " .. tostring(key))
    end,
})

return Keywords
