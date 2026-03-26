package.path = "./src/?.lua;" .. package.path
package.path = "./src/?/init.lua;" .. package.path

local inspect = require("inspect")
local lexer = require("frontend.lexer")
local parser = require("frontend.parser")
local codegen = require("backend.codegen")

local code = [[
extends Base

func init() {
    print("Hello world!")
}

func foo() {
lua {
    local a = b
}
}
]]

-- ===== Lexer ======
local tokens = lexer.token_pattern:match(code)
if not tokens then
    print("Lexer returned nil")
    return
end

print("=== Lexer Output ===")
for i, t in ipairs(tokens) do
    print(string.format("[%d] type = %s, value = %s", i, t.type, t.value or ""))
end

-- ===== Parser ======
local ast = parser.parseProgram(tokens)

-- ===== Kompletní AST print ======
print("\n=== AST Output (full) ===")
print(inspect(ast))

local lua_code = codegen.generate(ast)
print("\n=== Generated Lua Code ===")
print(lua_code)
