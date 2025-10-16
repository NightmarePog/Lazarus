require("compiler.types")
local utils = require("utils")


--local function insert_token() end

-- parses from tokens to AST
local function token_type_find(tbl: {TokenTypes}, key: string): TokenTypes, integer
    for k, v in ipairs(tbl) do
        if v.type == key then
            return v, k
        end
    end
end

local function parse(tokens: {TokenTypes}): ASTRoot 

    local root: ASTRoot
    utils.map_expression(tokens, function(v: {TokenTypes})
    local id_token   = token_type_find(v, "identifier")
    local type_token = token_type_find(v, "type")
    
    local value_token: TokenTypes
    for i, t in ipairs(v) do
        if t.type == "assign_operator_single" and v[i+1] then
            value_token = v[i+1]
            break
        end
    end

    if id_token then
        local var: NodeVariable = {}
        var.name  = id_token.value
        var.type  = (type_token and type_token.value or "undefined") as DataTypes
        var.value = (value_token and value_token.value or nil) as NodeDeclaration -- fix later Node declaration
        print("Var:", var.name, var.type, var.value)
    end
end)

    return root
    
end



return {
    parse = parse
}
