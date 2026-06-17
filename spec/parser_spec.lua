local Lexer  = require("frontend.lexer")
local Parser = require("frontend.parser")
local Error  = require("error")

local function parse(source)
    local tokens = Lexer.new(source):scan()
    return Parser.new(tokens, source):parse()
end

describe("Parser", function ()
    describe("valid programs", function ()
        it("parses a simple variable declaration", function ()
            local ast = parse("private x = 1")
            local decl = ast.body[1] --[[@as VariableDecl]]
            assert.equal("Program", ast.type)
            assert.equal(1, #ast.body)
            assert.equal("VariableDecl", decl.type)
            assert.equal("x", decl.name)
        end)

        it("parses a mutable declaration without an initialiser", function ()
            local ast = parse("private mut x")
            local decl = ast.body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", decl.type)
            assert.is_true(decl.mutable)
            assert.is_nil(decl.value)
        end)

        it("rejects an immutable declaration without an initialiser", function ()
            local ok, err = pcall(function () parse("private x") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, err.type)
            assert.matches("must be initialised", err.message)
        end)

        it("parses a public binding", function ()
            local decl = parse("public x = 1").body[1] --[[@as VariableDecl]]
            assert.equal("public", decl.visibility)
            assert.is_false(decl.mutable)
        end)

        it("parses a bare local binding as a VariableDecl", function ()
            local decl = parse("x = 1").body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", decl.type)
            assert.is_nil(decl.visibility)
            assert.is_false(decl.mutable)
        end)

        it("parses multiple statements", function ()
            local ast = parse("private x = 1\nprivate y = 2")
            assert.equal(2, #ast.body)
        end)

        it("parses nested arithmetic", function ()
            local ast = parse("private x = (1 + 2) * 3")
            local decl  = ast.body[1]  --[[@as VariableDecl]]
            local value = decl.value   --[[@as BinaryExpr]]
            assert.equal("VariableDecl", decl.type)
            assert.equal("BinaryExpr",   value.type)
        end)

        it("parses a string literal initialiser", function ()
            local ast = parse('private msg = "hello"')
            local decl = ast.body[1] --[[@as VariableDecl]]
            local lit  = decl.value  --[[@as LiteralExpr]]
            assert.equal("VariableDecl", decl.type)
            assert.equal("LiteralExpr",  lit.type)
            assert.equal("string",       lit.kind)
            assert.equal("hello",        lit.value)
        end)

        it("parses an identifier reference in an expression", function ()
            local ast  = parse("private x = 1\nprivate y = x")
            local y    = ast.body[2]  --[[@as VariableDecl]]
            local ident = y.value     --[[@as IdentifierExpr]]
            assert.equal("IdentifierExpr", ident.type)
            assert.equal("x",              ident.name)
        end)

        it("parses an empty program", function ()
            local ast = parse("")
            assert.equal("Program", ast.type)
            assert.equal(0, #ast.body)
        end)
    end)

    describe("error paths", function ()
        it("throws SYNTAX_ERROR for a missing identifier after 'private'", function ()
            local ok, err = pcall(function () parse("private = 5") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, err.type)
            assert.matches("Expected variable name after 'private'", err.message)
        end)

        it("throws SYNTAX_ERROR for an unclosed parenthesis", function ()
            local ok, err = pcall(function () parse("private x = (1 + 2") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, err.type)
        end)

        it("throws UNEXPECTED_TOKEN for '=' in statement position", function ()
            local ok, err = pcall(function () parse("= 5") end)
            assert.is_false(ok)
            -- ASSIGN is a keyword-only token; the dispatcher rejects it
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_TOKEN, err.type)
        end)

        it("throws on an empty grouped expression '()'", function ()
            local ok, err = pcall(function () parse("private x = ()") end)
            assert.is_false(ok)
        end)

        it("attaches source position to SYNTAX_ERROR from _consume", function ()
            local ok, err = pcall(function () parse("private 42") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, err.type)
            assert.is_number(err.line)
            assert.is_number(err.col)
        end)

        it("throws UNEXPECTED_EOF when input ends mid-expression", function ()
            local ok, err = pcall(function () parse("private x = 1 +") end)
            assert.is_false(ok)
            -- parser runs out of tokens inside _primary
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_EOF, err.type)
        end)
    end)
end)
