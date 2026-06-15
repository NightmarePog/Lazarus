local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Error     = require("error")

local function analyze(source)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()
    Schematic.analyze(ast, source)
    return ast
end

describe("Schematic", function ()
    describe("valid programs", function ()
        it("accepts a declaration and a later reference to it", function ()
            assert.has_no.errors(function ()
                analyze("private x = 1\nprivate y = x")
            end)
        end)

        it("accepts a constant referenced in a later expression", function ()
            assert.has_no.errors(function ()
                analyze("constant foo = 3\nprivate bar = foo + 1")
            end)
        end)
    end)

    describe("duplicate declarations", function ()
        it("rejects a redeclared name with SEMANTIC_ERROR and a position", function ()
            local ok, err = pcall(analyze, "private x = 1\nprivate x = 2")
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Duplicate declaration 'x'", err.message)
            assert.equal(2, err.line)
            assert.is_number(err.col)
        end)
    end)

    describe("undeclared identifiers", function ()
        it("rejects a reference to an unknown name with a source position", function ()
            local ok, err = pcall(analyze, "private y = nope")
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Undeclared identifier 'nope'", err.message)
            assert.equal(1, err.line)
            assert.equal(13, err.col)
        end)

        it("rejects self-reference in an initialiser", function ()
            local ok, err = pcall(analyze, "private x = x")
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
        end)
    end)

    describe("bare expression statements", function ()
        it("rejects a bare expression as a statement", function ()
            local ok, err = pcall(analyze, "private x = 1\nx + x")
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Bare expressions are not valid statements", err.message)
        end)
    end)
end)
