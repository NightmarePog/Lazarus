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
--- | "STATIC"
--- | "CONSTRUCTOR"
--- | "RETURN"
--- | "BODY_START"
--- | "BODY_END"
--- | "COMMA"
--- | "IF"
--- | "ELSE"
--- | "WHILE"
--- | "LOOP"
--- | "FOR"
--- | "BREAK"
--- | "TRUE"
--- | "FALSE"
--- | "AND"
--- | "OR"
--- | "NOT"
--- | "EQ"
--- | "NEQ"
--- | "LESS"
--- | "LESS_EQUAL"
--- | "GREATER"
--- | "GREATER_EQUAL"
--- | "PLUS_ASSIGN"
--- | "MINUS_ASSIGN"
--- | "STAR_ASSIGN"
--- | "SLASH_ASSIGN"
--- | "DIVIDE"
--- | "MODULO"
--- | "POWER"
--- | "CONCAT"
--- | "COLON"
--- | "DOT"
--- | "SEMICOLON"

--- Maps source-text strings to their `TokenType`.
--- Multi-character operators (`==`, `+=`, …) are matched by maximal munch in the
--- lexer, which tries the two-character key before the single-character one.
---@type table<string, TokenType>
local TOKENS_DATA = {
    ["private"] = "PRIVATE",
    ["public"] = "PUBLIC",
    ["mut"] = "MUTABLE",
    ["static"] = "STATIC",
    ["constructor"] = "CONSTRUCTOR",
    ["return"] = "RETURN",
    ["if"] = "IF",
    ["else"] = "ELSE",
    ["while"] = "WHILE",
    ["loop"] = "LOOP",
    ["for"] = "FOR",
    ["break"] = "BREAK",
    ["true"] = "TRUE",
    ["false"] = "FALSE",
    ["and"] = "AND",
    ["or"] = "OR",
    ["not"] = "NOT",
    ["="] = "ASSIGN",
    ["+"] = "PLUS",
    ["-"] = "MINUS",
    ["*"] = "MULTIPLY",
    ["/"] = "DIVIDE",
    ["%"] = "MODULO",
    ["^"] = "POWER",
    ["++"] = "CONCAT",
    ["=="] = "EQ",
    ["!="] = "NEQ",
    ["<"] = "LESS",
    ["<="] = "LESS_EQUAL",
    [">"] = "GREATER",
    [">="] = "GREATER_EQUAL",
    ["+="] = "PLUS_ASSIGN",
    ["-="] = "MINUS_ASSIGN",
    ["*="] = "STAR_ASSIGN",
    ["/="] = "SLASH_ASSIGN",
    ["("] = "LEFT_BRACKET",
    [")"] = "RIGHT_BRACKET",
    ["{"] = "BODY_START",
    ["}"] = "BODY_END",
    [","] = "COMMA",
    [":"] = "COLON",
    ["."] = "DOT",
    [";"] = "SEMICOLON"
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
    DIVIDE = true,
    MODULO = true,
    POWER = true,
    CONCAT = true,
    LEFT_BRACKET = true,
    RIGHT_BRACKET = true,
    -- Tokens that can begin an expression: boolean literals and the `not` prefix.
    TRUE = true,
    FALSE = true,
    NOT = true
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
