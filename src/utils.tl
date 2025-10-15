require("compiler.types")
local tokens_lib = require("compiler.tokens_lib")

local function map(tbl: table, func: function(any, any)) 
   for k, v in pairs(tbl) do
      func(k, v)
   end
end

local function table_clear(t: table) 
   for k in pairs(t) do
    t[k] = nil
   end

end

local function map_expression(tokens: {TokenTypes}, func: function(token_line: {TokenTypes}))
   local buffer: {TokenTypes} = {} 
   for _, v in ipairs(tokens) do
      if v.type ~= "expression_end" then
         table.insert(buffer, v)
      else
         func(buffer)
         table_clear(buffer)
      end
   end
end


local function map_func(tokens: Tokens, func: function(token_line: Tokens))
   local buffer: Tokens = {} 
   for _, v in ipairs(tokens) do
      if tokens_lib.get_token_type(v) ~= "operator_function" then
         table.insert(buffer, v)
      else
         func(buffer)
         table_clear(buffer)
      end
   end
end


return {
   map = map,
   map_expression = map_expression,
   map_func = map_func
}