--- Bool-only condition tests.
---
--- The language has no truthiness, so `if`/`while`/`for` conditions must be
--- booleans. The check is best-effort: it rejects only values that are *provably*
--- non-boolean (number/string literals, collections, arithmetic/concat results,
--- and built-ins that return a number/Option), and stays silent on anything that
--- might be a boolean (a name, a field, a call).

local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Schematic = require("frontend.schematic")

local function analyze(source)
    Schematic.analyze(Parser.new(Lexer.new(source):scan(), source):parse(), source)
end

--- Wrap a condition expression in a `static` method so it analyses in context.
local function with_if(cond) return "static f() {\n if " .. cond .. " { } \n}" end
local function with_while(cond) return "static f() {\n while " .. cond .. " { } \n}" end

describe("bool-only conditions", function()
    describe("accepts maybe-boolean conditions", function()
        it("a comparison", function()
            assert.has_no.errors(function() analyze(with_if("1 < 2")) end)
        end)

        it("a boolean literal", function()
            assert.has_no.errors(function() analyze(with_if("true")) end)
        end)

        it("a logical combination", function()
            assert.has_no.errors(function() analyze(with_if("1 < 2 and 3 > 2")) end)
        end)

        it("a bound boolean variable", function()
            assert.has_no.errors(
                function() analyze("static f() { mut b = true\n if b { b = false } }") end
            )
        end)

        it("a while condition that is a comparison", function()
            assert.has_no.errors(
                function() analyze("static f() { mut n = 0\n while n < 3 { n = n + 1 } }") end
            )
        end)
    end)

    describe("rejects provably non-boolean conditions", function()
        it("a number literal", function()
            assert.has_error(function() analyze(with_if("5")) end)
        end)

        it("a string literal", function()
            assert.has_error(function() analyze(with_if('"x"')) end)
        end)

        it("an arithmetic result", function()
            assert.has_error(
                function() analyze("static f() { mut x = 1\n if x + 1 { } }") end
            )
        end)

        it("a string concatenation", function()
            assert.has_error(
                function() analyze('static f() { mut s = "a"\n if s ++ "b" { } }') end
            )
        end)

        it("a non-boolean condition in a while", function()
            assert.has_error(function() analyze(with_while("5")) end)
        end)
    end)
end)
