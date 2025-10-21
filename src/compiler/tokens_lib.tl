require("compiler.types")
local type TokenMap = { string: Token }

-- Syntax value to token
local tokens = {
    types = {
        string = "type",
        number = "type",
        bool = "type",
        undefined = "type",
        func = "type",
        class = "type",
    } as TokenMap,

    variables = {
        ["..."] = "variables_undefined_count",
        ["let"] = "keyword",
        ["extern"] = "keyword"
    } as TokenMap,

    control = {
        ["return"] = "keyword",
    } as TokenMap,

    compoundOperators = {
        ["=="] = "operator",
        ["!="] = "operator",
        ["<="] = "operator",
        [">="] = "operator",
        ["++"] = "operator",
        ["--"] = "operator",
        ["&&"] = "operator",
        ["||"] = "operator",
        ["=>"] = "operator",
    } as TokenMap,

    singleOperators = {
        ["+"] = "operator",
        ["-"] = "operator",
        ["*"] = "operator",
        ["/"] = "operator",
        ["%"] = "operator",
        ["<"] = "operator",
        [">"] = "operator",
        ["="] = "operator",
        ["!"] = "operator",
    } as TokenMap,

    symbols = {
        ["("] = "paren_open",
        [")"] = "paren_close",
        ["{"] = "brace_open",
        ["}"] = "brace_close",
        ["["] = "bracket_open",
        ["]"] = "bracket_close",
        [";"] = "expression_end",
        [","] = "comma",
        ["."] = "dot",
        [":"] = "double_dots",
    } as TokenMap,

    index = {} as TokenMap,
}

-- adds new token into a table
local function add(tbl: TokenMap)
    for k, v in pairs(tbl) do
        tokens.index[k] = v
    end
end

add(tokens.types)
add(tokens.variables)
add(tokens.control)
add(tokens.compoundOperators)
add(tokens.singleOperators)
add(tokens.symbols)

-- gets token from a table
function tokens.get_token_type(token: string):  Token | nil
    return tokens.index[token]
end

return tokens
