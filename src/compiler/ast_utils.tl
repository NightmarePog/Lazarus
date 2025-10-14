require("compiler.types")
local tokens_lib = require("compiler.tokens_lib")

local function map_exp_starts(tokens: Tokens, func: function) 
    for i, token in ipairs(tokens) do
        local expression_start = 0
        local cur_token_type = tokens_lib.get_token_type(token)
        if (cur_token_type == tokens_lib["symbols"]["expression_end"]) then
            expression_start = i
            func(expression_start+1)
        end
    end
end

return {
    map_exp_starts = map_exp_starts
}