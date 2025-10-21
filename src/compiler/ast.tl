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
local function parse_var(v: {TokenTypes})
    local data_type = token_type_find(v, "type")
    local name = token_type_find(v, "identifier")
    if not name then
        error("no name for the variable found")
    end

    if not data_type then
        data_type = {
            type = "type",
            value = "undefined"
        }
    end
    -- if val then bla bla
    local var: NodeVariable = {
        type = data_type.value as DataTypes,
        name = name.value,

    }
    for i, val in pairs(var as {string:any}) do
        print(i, val)

    end

    --[[
    global interface NodeVariable is Node
   where self.node_type == "Variable"
   type: DataTypes
   name: string
   value: NodeDeclaration | NodeFunction
   value_assigned: boolean
end
--]]
end


local function parse(tokens: {TokenTypes}): ASTRoot 

    local root: ASTRoot
    utils.map_expression(tokens, function(v: {TokenTypes})
        local keyword = token_type_find(v, "keyword")
        if keyword.value == "let" then
            parse_var(v)
        else
            error("No keyword found TODO this")
        end
    end)
    return root
    
end



return {
    parse = parse
}
