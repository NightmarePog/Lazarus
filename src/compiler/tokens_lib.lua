local tokens = {}

tokens.types = {
    ["string"] = "type",
    ["number"] = "type",
    ["bool"] = "type",
    ["nil"] = "type",
    ["func"] = "type",
    ["class"] = "type"
}

tokens.variables = {
    ["mut"] = "variable_modifier",
    ["export"] = "export_keyword",
    ["let"] = "variable_initilization"
}

tokens.class = {
    ["public"] = "access_modifier",
    ["private"] = "access_modifier",
    ["constructor"] = "special_method"
}

tokens.control = {
    ["if"] = "control",
    ["else"] = "control",
    ["while"] = "loop",
    ["for"] = "loop",
    ["break"] = "loop_control",
    ["continue"] = "loop_control",
    ["return"] = "return_keyword"
}

tokens.imports = {
    ["import"] = "import",
    ["from"] = "import",
    ["as"] = "import"
}

tokens.compoundOperators = {
    ["=="] = "operator_compound",
    ["!="] = "operator_compound",
    ["<="] = "operator_compound",
    [">="] = "operator_compound",
    ["++"] = "operator_compound",
    ["--"] = "operator_compound",
    ["&&"] = "operator_compound",
    ["||"] = "operator_compound",
    ["=>"] = "operator_compound"
}

tokens.singleOperators = {
    ["+"] = "operator_single",
    ["-"] = "operator_single",
    ["*"] = "operator_single",
    ["/"] = "operator_single",
    ["%"] = "operator_single",
    ["<"] = "operator_single",
    [">"] = "operator_single",
    ["="] = "operator_single",
    ["!"] = "operator_single"
}

tokens.symbols = {
    ["("] = "paren_open",
    [")"] = "paren_close",
    ["{"] = "brace_open",
    ["}"] = "brace_close",
    ["["] = "bracket_open",
    ["]"] = "bracket_close",
    [";"] = "semicolon",
    [","] = "comma",
    ["."] = "dot",
    [":"] = "colon"
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