package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local Lexer = require "frontend.lexer"
local Parser = require "frontend.parser"
local Schematic = require "frontend.schematic"
local Optimizer = require "frontend.optimizer"
local Codegen = require "backend"

local source = [[
constant foo = 3+2
private var_name = 5+5-2*(2+foo)
]]

---@param val    any
---@param indent integer?
---@return string?
local function dump(val, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)

    if type(val) ~= "table" then
        return tostring(val or "")
    end

    local lines = { "{" }
    for k, v in pairs(val) do
        local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
        table.insert(lines, pad .. "  " .. key .. " = " .. dump(v, indent + 1))
    end
    table.insert(lines, pad .. "}")
    return table.concat(lines, "\n")
end

local function main()
    local tokens = Lexer.new(source):scan()
    local ast = Parser.new(tokens, source):parse()
    Schematic.analyze(ast, source)
    local opt = Optimizer.optimize(ast)
    print(dump(opt))
    local output = Codegen.new(opt):generate()
    print(output)
end

main()
