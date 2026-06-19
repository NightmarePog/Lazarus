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

    describe("boolean / unary / comparison / logical expressions", function ()
        local function value_of(src)
            return parse("private x = " .. src).body[1].value
        end

        it("parses 'true' as a boolean literal", function ()
            local lit = value_of("true") --[[@as LiteralExpr]]
            assert.equal("LiteralExpr", lit.type)
            assert.equal("boolean", lit.kind)
            assert.equal(true, lit.value)
        end)

        it("parses 'false' as a boolean literal", function ()
            local lit = value_of("false") --[[@as LiteralExpr]]
            assert.equal("boolean", lit.kind)
            assert.equal(false, lit.value)
        end)

        it("parses 'not a' as a UnaryExpr", function ()
            local u = value_of("not a") --[[@as UnaryExpr]]
            assert.equal("UnaryExpr", u.type)
            assert.equal("NOT", u.op)
            assert.equal("IdentifierExpr", u.operand.type)
        end)

        local comparisons = {
            { "a == b", "EQ" }, { "a != b", "NEQ" }, { "a < b", "LESS" },
            { "a <= b", "LESS_EQUAL" }, { "a > b", "GREATER" }, { "a >= b", "GREATER_EQUAL" },
        }
        for _, case in ipairs(comparisons) do
            it("parses '" .. case[1] .. "' as BinaryExpr " .. case[2], function ()
                local b = value_of(case[1]) --[[@as BinaryExpr]]
                assert.equal("BinaryExpr", b.type)
                assert.equal(case[2], b.op)
            end)
        end

        local arithmetic = {
            { "a / b", "DIVIDE" }, { "a % b", "MODULO" },
            { "a ^ b", "POWER" }, { "a ++ b", "CONCAT" },
        }
        for _, case in ipairs(arithmetic) do
            it("parses '" .. case[1] .. "' as BinaryExpr " .. case[2], function ()
                local b = value_of(case[1]) --[[@as BinaryExpr]]
                assert.equal("BinaryExpr", b.type)
                assert.equal(case[2], b.op)
            end)
        end

        it("binds '/' at the multiplicative level (tighter than '+')", function ()
            -- a + b / c  ->  a + (b / c)
            local top = value_of("a + b / c") --[[@as BinaryExpr]]
            assert.equal("PLUS", top.op)
            assert.equal("BinaryExpr", top.right.type)
            assert.equal("DIVIDE", top.right.op)
        end)

        it("binds '^' tighter than '*'", function ()
            -- a * b ^ c  ->  a * (b ^ c)
            local top = value_of("a * b ^ c") --[[@as BinaryExpr]]
            assert.equal("MULTIPLY", top.op)
            assert.equal("BinaryExpr", top.right.type)
            assert.equal("POWER", top.right.op)
        end)

        it("parses 'a and b' as BinaryExpr AND", function ()
            local b = value_of("a and b") --[[@as BinaryExpr]]
            assert.equal("AND", b.op)
        end)

        it("parses 'a or b' as BinaryExpr OR", function ()
            local b = value_of("a or b") --[[@as BinaryExpr]]
            assert.equal("OR", b.op)
        end)

        it("binds 'and' tighter than 'or'", function ()
            -- a or b and c  ->  a or (b and c)
            local top = value_of("a or b and c") --[[@as BinaryExpr]]
            assert.equal("OR", top.op)
            assert.equal("BinaryExpr", top.right.type)
            assert.equal("AND", top.right.op)
        end)

        it("binds arithmetic tighter than comparison", function ()
            -- a + b == c  ->  (a + b) == c
            local top = value_of("a + b == c") --[[@as BinaryExpr]]
            assert.equal("EQ", top.op)
            assert.equal("BinaryExpr", top.left.type)
            assert.equal("PLUS", top.left.op)
        end)

        it("binds unary 'not' tighter than comparison (Lua semantics)", function ()
            -- not a == b  ->  (not a) == b
            local top = value_of("not a == b") --[[@as BinaryExpr]]
            assert.equal("EQ", top.op)
            assert.equal("UnaryExpr", top.left.type)
        end)
    end)

    describe("control-flow statements", function ()
        it("parses an if statement into a single clause", function ()
            local s = parse("if a { x = 1 }").body[1] --[[@as IfStmt]]
            assert.equal("IfStmt", s.type)
            assert.equal(1, #s.clauses)
            assert.equal("IdentifierExpr", s.clauses[1].condition.type)
            assert.equal(1, #s.clauses[1].body)
            assert.is_nil(s.else_body)
        end)

        it("parses if / else if / else", function ()
            local s = parse("if a { x = 1 } else if b { x = 2 } else { x = 3 }").body[1] --[[@as IfStmt]]
            assert.equal(2, #s.clauses)
            assert.equal("IdentifierExpr", s.clauses[2].condition.type)
            assert.is_table(s.else_body)
            assert.equal(1, #s.else_body)
        end)

        it("parses a plain else (no else-if)", function ()
            local s = parse("if a { x = 1 } else { x = 2 }").body[1] --[[@as IfStmt]]
            assert.equal(1, #s.clauses)
            assert.equal(1, #s.else_body)
        end)

        it("parses a while loop", function ()
            local s = parse("while a { x = 1 }").body[1] --[[@as WhileStmt]]
            assert.equal("WhileStmt", s.type)
            assert.equal("IdentifierExpr", s.condition.type)
            assert.equal(1, #s.body)
        end)

        it("parses an infinite loop", function ()
            local s = parse("loop { x = 1 }").body[1] --[[@as LoopStmt]]
            assert.equal("LoopStmt", s.type)
            assert.equal(1, #s.body)
        end)

        it("parses break inside a loop", function ()
            local s = parse("loop { break }").body[1] --[[@as LoopStmt]]
            assert.equal("BreakStmt", s.body[1].type)
        end)

        it("parses a C-style for without parens", function ()
            local s = parse("for i = 0; i < n; i = i + 1 { x = 1 }").body[1] --[[@as ForStmt]]
            assert.equal("ForStmt", s.type)
            assert.equal("VariableDecl", s.init.type)
            assert.equal("i", s.init.name)
            assert.equal("BinaryExpr", s.condition.type)
            assert.equal("LESS", s.condition.op)
            assert.equal("VariableDecl", s.step.type)
            assert.equal(1, #s.body)
        end)

        it("allows empty for clauses", function ()
            local s = parse("for ; ; { break }").body[1] --[[@as ForStmt]]
            assert.equal("ForStmt", s.type)
            assert.is_nil(s.init)
            assert.is_nil(s.condition)
            assert.is_nil(s.step)
        end)

        it("accepts compound assignment as the for step", function ()
            local s = parse("for i = 0; i < n; i += 1 { x = 1 }").body[1] --[[@as ForStmt]]
            assert.equal("VariableDecl", s.step.type)
            assert.equal("BinaryExpr", s.step.value.type)
            assert.equal("PLUS", s.step.value.op)
        end)
    end)

    describe("compound assignment", function ()
        it("desugars 'i += 1' to 'i = i + 1'", function ()
            local s = parse("i += 1").body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", s.type)
            assert.equal("i", s.name)
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", v.type)
            assert.equal("PLUS", v.op)
            assert.equal("IdentifierExpr", v.left.type)
            assert.equal("i", v.left.name)
        end)

        it("desugars '*=' to a MULTIPLY reassignment", function ()
            local v = parse("i *= 2").body[1].value --[[@as BinaryExpr]]
            assert.equal("MULTIPLY", v.op)
        end)

        it("desugars '-=' to a MINUS reassignment", function ()
            local v = parse("i -= 2").body[1].value --[[@as BinaryExpr]]
            assert.equal("MINUS", v.op)
        end)

        it("desugars '/=' to a DIVIDE reassignment", function ()
            local v = parse("i /= 2").body[1].value --[[@as BinaryExpr]]
            assert.equal("DIVIDE", v.op)
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
