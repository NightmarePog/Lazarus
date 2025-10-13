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


-- not sure where to put these :p

local expression_start = {
    start = 0,
    _all_expressions: {integer} = {},
    current = 1

}

function expression_start:new(tokens: Tokens) 
    for i, token in ipairs(tokens) do
        local cur_token_type = tokens_lib.get_token_type(token)
        if (cur_token_type == tokens_lib["symbols"]["expression_end"]) then
            table.insert(self._all_expressions, i+1)
        end

    end
end

function expression_start:next(): integer
    self.current = self.current+1
    self.start = self._all_expressions[self.current]
    return self.start
end


function expression_start:reset() 
    self.start = 0
end


function expression_start:get_current(): number
    return self.start
end





return {
    parse = parse
}
