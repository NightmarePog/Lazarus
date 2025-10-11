local tokens: {
    types: { [string]: string },
    variables: { [string]: string },
    control: { [string]: string },
    compoundOperators: { [string]: string },
    singleOperators: { [string]: string },
    symbols: { [string]: string },
    index: { [string]: string },
    getTokenType: (string) -> string?
} = {}

tokens.types = {
    string = "type_string",
    number = "type_number",
    bool = "type_bool",
    undefined = "type_undefined",
    func = "type_function",
    class = "type_class",
}

tokens.variables = {
    ["..."] = "variables_undefined_count"
}

tokens.control = {
    return = "returns_keyword"
}

tokens.compoundOperators = {
    ["=="] = "operator_equals",
    ["!="] = "operator_not_equals",
    ["<="] = "operator_less_or_equals",
    [">="] = "operator_greater_or_equals",
    ["++"] = "operator_increment",
    ["--"] = "operator_decrement",
    ["&&"] = "operator_and",
    ["||"] = "operator_or",
    ["=>"] = "operator_function"
}

tokens.singleOperators = {
    ["+"] = "laz_plus_operator_single",
    ["-"] = "laz_minus_operator_single",
    ["*"] = "laz_times_operator_single",
    ["/"] = "laz_division_operator_single",
    ["%"] = "laz_modulo_operator_single",
    ["<"] = "laz_less_operator_single",
    [">"] = "laz_greater_operator_single",
    ["="] = "laz_assign_operator_single",
    ["!"] = "laz_not_operator_single"
}

tokens.symbols = {
    ["("] = "laz_paren_open",
    [")"] = "laz_paren_close",
    ["{"] = "laz_brace_open",
    ["}"] = "laz_brace_close",
    ["["] = "laz_bracket_open",
    ["]"] = "laz_bracket_close",
    [";"] = "laz_expression_end",
    [","] = "laz_comma",
    ["."] = "laz_dot",
    [":"] = "laz_colon"
}

tokens.index = {}

local function add(tbl: { [string]: string })
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

function tokens.getTokenType(token: string): string?
    return tokens.index[token]
end

return tokens
