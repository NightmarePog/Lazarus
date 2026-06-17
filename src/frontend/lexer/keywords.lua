--- Keyword and operator tables used by the lexer and the statement dispatcher.

local Keywords = {}

---@alias TokenType
--- | "PRIVATE"
--- | "PUBLIC"
--- | "MUTABLE"
--- | "ASSIGN"
--- | "PLUS"
--- | "MINUS"
--- | "IDENTIFIER"
--- | "NUMBER"
--- | "STRING"
--- | "MULTIPLY"
--- | "LEFT_BRACKET"
--- | "RIGHT_BRACKET"
--- | "FUNCTION"
--- | "RETURN"
--- | "BODY_START"
--- | "BODY_END"
--- | "COMMA"

--- Maps source-text strings to their `TokenType`.
---@type table<string, TokenType>
local TOKENS_DATA = {
    ["private"] = "PRIVATE",
    ["public"] = "PUBLIC",
    ["mut"] = "MUTABLE",
    ["fn"] = "FUNCTION",
    ["return"] = "RETURN",
    ["="] = "ASSIGN",
    ["+"] = "PLUS",
    ["-"] = "MINUS",
    ["*"] = "MULTIPLY",
    ["("] = "LEFT_BRACKET",
    [")"] = "RIGHT_BRACKET",
    ["{"] = "BODY_START",
    ["}"] = "BODY_END",
    [","] = "COMMA"
}

--- Truly read-only view of `TOKENS_DATA`. Because lookups go through an empty
--- proxy table, *every* assignment hits `__newindex` — including overwriting an
--- existing key — so the map cannot be mutated at all after definition.
---@type table<string, TokenType>
local TOKENS = setmetatable({}, {
    __index = TOKENS_DATA,
    __newindex = function (_, key)
        error("Attempt to modify read-only Keywords.TOKENS: " .. tostring(key))
    end,
    __metatable = false
})
Keywords.TOKENS = TOKENS

--- Token types that may appear in expressions or as primary values.
--- Explicit list — add new operator token types here when they are introduced.
--- Keywords (PRIVATE, ASSIGN, …) are intentionally absent so they never
--- silently fall through to expression-statement parsing.
---@type table<string, boolean>
local VALID_TYPES = {
    NUMBER = true,
    STRING = true,
    IDENTIFIER = true,
    PLUS = true,
    MINUS = true,
    MULTIPLY = true,
    LEFT_BRACKET = true,
    RIGHT_BRACKET = true
}

--- Return `true` when `token_type` cannot legally appear in expression
--- position (i.e. it is a keyword-only or assignment-only token).
---@param token_type string
---@return boolean
function Keywords.is_invalid_token_type(token_type)
    return not VALID_TYPES[token_type]
end

setmetatable(Keywords, {
    __index = TOKENS,

    __newindex = function (_, key)
        error("Attempt to modify read-only Keywords table: " .. tostring(key))
    end
})

return Keywords
