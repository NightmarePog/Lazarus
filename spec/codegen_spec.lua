local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen   = require("backend")

local load_chunk = loadstring or load

--- Run the full pipeline and return the generated Lua source string.
local function compile(source)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()
    Schematic.analyze(ast, source)
    ast = Optimizer.optimize(ast)
    return Codegen.new(ast):generate()
end

describe("Codegen", function ()
    describe("emission", function ()
        it("emits a variable declaration as a local", function ()
            assert.equal("local x = 5", compile("private x = 5"))
        end)

        it("emits a valueless declaration as a bare local", function ()
            assert.equal("local x", compile("private x"))
        end)

        it("emits a constant declaration as a local", function ()
            assert.equal("local foo = 5", compile("constant foo = 3 + 2"))
        end)

        it("parenthesises nested binary operands", function ()
            -- `a` is a variable, so the sum is not folded and must round-trip.
            assert.equal("local a = 1\nlocal b = (a + 1) * 2",
                compile("private a = 1\nprivate b = (a + 1) * 2"))
        end)

        it("emits string literals via %q", function ()
            assert.equal('local s = "hi"', compile('private s = "hi"'))
        end)
    end)

    describe("output is valid Lua", function ()
        local cases = {
            "private x = 5",
            "private x",
            "constant foo = 3 + 2\nprivate bar = foo + 1",
            "private a = 1\nprivate b = (a + 1) * 2",
            'private s = "hello"',
        }

        for _, src in ipairs(cases) do
            it("loads: " .. src:gsub("\n", " / "), function ()
                local out = compile(src)
                local chunk, err = load_chunk(out)
                assert.is_truthy(chunk, "generated code failed to load: " .. tostring(err) .. "\n" .. out)
            end)
        end
    end)
end)
