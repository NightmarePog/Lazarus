require("compiler.types")
local tokens_lib = require("compiler.tokens_lib")

-- parses from tokens to AST
local function parse(tokens: Tokens): ASTRoot 
    local root: ASTRoot

    for i, token in ipairs(tokens) do
        local expression_start = 0
        local cur_token_type = tokens_lib.get_token_type(token)
        if (cur_token_type == tokens_lib["symbols"]["expression_end"]) then
            expression_start = i
            print(expression_start)
        end

    end
    return root
    
end

local expression_start_locator = {
    expression_start = 0,
}

function expression_start_locator.reset_expression_start()
    expression_start_locator.expression_start = 0
end



return {
    parse = parse
}
