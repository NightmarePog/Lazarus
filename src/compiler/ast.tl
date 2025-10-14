require("compiler.types")
local utils = require("compiler.ast_utils")



-- parses from tokens to AST
local function parse(tokens: Tokens): ASTRoot 
    local root: ASTRoot
    utils.map_exp_starts(tokens, function(start) print("start:", start) end)
    return root
    
end



return {
    parse = parse
}
