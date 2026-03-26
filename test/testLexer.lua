-- tests/testLexer.lua

-- Přidáme src do package.path
package.path        = "./src/?.lua;" .. package.path
package.path        = "./src/?/init.lua;" .. package.path

local lpeg          = require("lpeg")
local lexer         = require("lexer")
local busted        = require("busted")

local token_pattern = lexer.token_pattern

describe("Lexer tests for .laz language", function()
    it("should tokenize let declaration", function()
        local code = "let x: number = 10"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "LET")
        assert.are.equal(tokens[1].value, "let")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "x")

        assert.are.equal(tokens[3].type, "COLON")
        assert.are.equal(tokens[3].value, ":")

        assert.are.equal(tokens[4].type, "IDENT")
        assert.are.equal(tokens[4].value, "number")

        assert.are.equal(tokens[5].type, "EQ")
        assert.are.equal(tokens[5].value, "=")

        assert.are.equal(tokens[6].type, "NUMBER")
        assert.are.equal(tokens[6].value, "10")
    end)

    it("should tokenize const declaration", function()
        local code = "const PI: number = 3.14"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "CONST")
        assert.are.equal(tokens[1].value, "const")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "PI")

        assert.are.equal(tokens[3].type, "COLON")
        assert.are.equal(tokens[3].value, ":")

        assert.are.equal(tokens[4].type, "IDENT")
        assert.are.equal(tokens[4].value, "number")

        assert.are.equal(tokens[5].type, "EQ")
        assert.are.equal(tokens[5].value, "=")

        assert.are.equal(tokens[6].type, "NUMBER")
        assert.are.equal(tokens[6].value, "3.14")
    end)

    it("should tokenize func and parameters", function()
        local code = "func init()"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "FUNC")
        assert.are.equal(tokens[1].value, "func")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "init")

        assert.are.equal(tokens[3].type, "LPAREN")
        assert.are.equal(tokens[3].value, "(")

        assert.are.equal(tokens[4].type, "RPAREN")
        assert.are.equal(tokens[4].value, ")")
    end)

    it("should tokenize extends keyword", function()
        local code = "extends ParentClass"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "EXTENDS")
        assert.are.equal(tokens[1].value, "extends")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "ParentClass")
    end)

    it("should tokenize lua block", function()
        local code = "lua { print(self) }"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "LUA_BLOCK")
        assert.are.equal(tokens[1].value, " print(self) ")
    end)

    it("should tokenize import", function()
        local code = "import Math"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "IMPORT")
        assert.are.equal(tokens[1].value, "import")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "Math")
    end)

    it("should tokenize identifiers", function()
        local code = "_myVar someVar123"
        local tokens = token_pattern:match(code)

        assert.are.equal(tokens[1].type, "IDENT")
        assert.are.equal(tokens[1].value, "_myVar")

        assert.are.equal(tokens[2].type, "IDENT")
        assert.are.equal(tokens[2].value, "someVar123")
    end)
end)
