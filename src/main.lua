package.path = "./src/?.lua;" .. package.path
package.path = "./src/?/init.lua;" .. package.path

local lexer = require("lexer")
local token_pattern = lexer.token_pattern

local code = [[
lua { print(self) }
]]

-- Funkce pro tisk tokenů
local function print_tokens(tokens)
    for i, t in ipairs(tokens) do
        if t then
            print(string.format("[%d] type = %s, value = %s", i, t.type, t.value))
        end
    end
end

-- Spustíme lexer
local tokens = token_pattern:match(code)

if not tokens then
    print("Lex returned nil")
else
    print("=== Lexer Output ===")
    print_tokens(tokens)
end
