local module = {}

-- základní datové typy
module.types = {
    ["string"] = true,
    ["number"] = true,
    ["boolean"] = true,
    ["nil"] = true,
    ["func"] = true,
    ["class"] = true
}

-- proměnné a konstanty
module.variables = {
    ["const"] = true,
    ["export"] = true,
    ["local"] = true
}

-- funkce a třídy
module.class_func = {
    ["func"] = true,
    ["constructor"] = true,
    ["public"] = true,
    ["private"] = true,
    ["static"] = true
}

-- řízení toku
module.control = {
    ["if"] = true,
    ["else"] = true,
    ["while"] = true,
    ["for"] = true,
    ["break"] = true,
    ["continue"] = true
}

-- importy a moduly
module.imports = {
    ["import"] = true,
    ["from"] = true,
    ["as"] = true,
    ["module"] = true
}

-- error handling (budoucí)
module.error = {
    ["try"] = true,
    ["catch"] = true,
    ["finally"] = true
}

-- logické a relační operátory
module.operands = {
    ["+"] = true,
    ["-"] = true,
    ["*"] = true,
    ["/"] = true,
    ["%"] = true,
    ["++"] = true,
    ["--"] = true,
    ["=="] = true,
    ["!="] = true,
    ["<"] = true,
    [">"] = true,
    ["<="] = true,
    [">="] = true,
    ["&&"] = true,
    ["||"] = true,
    ["!"] = true
}

return module
