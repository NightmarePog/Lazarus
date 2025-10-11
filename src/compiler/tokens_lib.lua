local tokens = {}

tokens.types = {
    ["string"] = "type",
    ["number"] = "type",
    ["bool"] = "type",
    ["undefined"] = "type",
    ["func"] = "type",
    ["class"] = "type",
}

tokens.variables = {
    ["mut"] = "laz_mut_variable_modifier",
    ["export"] = "laz_export_keyword",
    ["let"] = "laz_variable_initilization",
    ["..."] = "laz_undefined_count_parameters"
}

tokens.class = {
    ["public"] = "laz_access_modifier",
    ["private"] = "laz_access_modifier",
    ["constructor"] = "laz_special_method"
}

tokens.control = {
    ["if"] = "laz_if_control",
    ["else"] = "laz_else_control",
    ["while"] = "laz_while_loop",
    ["for"] = "laz_for_loop",
    ["break"] = "loop_break_control",
    ["continue"] = "loop_continue_control",
    ["return"] = "returns_keyword"
}

tokens.imports = {
    ["import"] = "laz_import",
    ["from"] = "laz_from",
    ["as"] = "laz_as"
}

tokens.compoundOperators = {
    ["=="] = "laz_equals_operator_compound",
    ["!="] = "laz_not_equals_operator_compound",
    ["<="] = "laz_less_or_equal_operator_compound",
    [">="] = "laz_greater_or_equaloperator_compound",
    ["++"] = "laz_incrimement_operator_compound",
    ["--"] = "laz_decrement_operator_compound",
    ["&&"] = "laz_and_operator_compound",
    ["||"] = "laz_or_operator_compound",
    ["=>"] = "laz_func_arrow_operator_compound"
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

local function add(tbl)
    for k, v in pairs(tbl) do
        tokens.index[k] = v
    end
end

add(tokens.types)
add(tokens.variables)
add(tokens.class)
add(tokens.control)
add(tokens.imports)
add(tokens.compoundOperators)
add(tokens.singleOperators)
add(tokens.symbols)

function tokens.getTokenType(token)
    return tokens.index[token]
end

return tokens