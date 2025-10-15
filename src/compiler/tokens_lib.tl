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
        ["let"] = "declare_variable",
        ["extern"] = "extern_variable"
    } as TokenMap,

    control = {
        ["return"] = "returns_keyword",
    } as TokenMap,

    compoundOperators = {
        ["=="] = "operator_equals",
        ["!="] = "operator_not_equals",
        ["<="] = "operator_less_or_equals",
        [">="] = "operator_greater_or_equals",
        ["++"] = "operator_increment",
        ["--"] = "operator_decrement",
        ["&&"] = "operator_and",
        ["||"] = "operator_or",
        ["=>"] = "operator_function",
    } as TokenMap,

    singleOperators = {
        ["+"] = "plus_operator_single",
        ["-"] = "minus_operator_single",
        ["*"] = "times_operator_single",
        ["/"] = "division_operator_single",
        ["%"] = "modulo_operator_single",
        ["<"] = "less_operator_single",
        [">"] = "greater_operator_single",
        ["="] = "assign_operator_single",
        ["!"] = "not_operator_single",
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
