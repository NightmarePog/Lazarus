local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Error = require("error")

local function parse(source)
    local tokens = Lexer.new(source):scan()
    return Parser.new(tokens, source):parse()
end

describe("Parser", function()
    describe("valid programs", function()
        it("parses a simple variable declaration", function()
            local ast = parse("private x = 1")
            local decl = ast.body[1] --[[@as VariableDecl]]
            assert.equal("Program", ast.type)
            assert.equal(1, #ast.body)
            assert.equal("VariableDecl", decl.type)
            assert.equal("x", decl.name)
        end)

        it("parses a mutable declaration without an initialiser", function()
            local ast = parse("private mut x")
            local decl = ast.body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", decl.type)
            assert.is_true(decl.mutable)
            assert.is_nil(decl.value)
        end)

        it("allows an instance property without an initialiser", function()
            -- `private x` (no `static`) is an instance property; it may be
            -- declared without a value and defaults to nil.
            local decl = parse("private x").body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", decl.type)
            assert.is_nil(decl.value)
            assert.is_false(decl.is_static)
        end)

        it("rejects an immutable static member without an initialiser", function()
            local ok, err = pcall(function() parse("private static x") end)
            assert.is_false(ok)
            local e = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, e.type)
            assert.matches("must be initialised", e.message)
        end)

        it("parses a public binding", function()
            local decl = parse("public x = 1").body[1] --[[@as VariableDecl]]
            assert.equal("public", decl.visibility)
            assert.is_false(decl.mutable)
        end)

        it("parses a bare local binding as a VariableDecl", function()
            local decl = parse("x = 1").body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", decl.type)
            assert.is_nil(decl.visibility)
            assert.is_false(decl.mutable)
        end)

        it("parses multiple statements", function()
            local ast = parse("private x = 1\nprivate y = 2")
            assert.equal(2, #ast.body)
        end)

        it("parses nested arithmetic", function()
            local ast = parse("private x = (1 + 2) * 3")
            local decl = ast.body[1] --[[@as VariableDecl]]
            local value = decl.value --[[@as BinaryExpr]]
            assert.equal("VariableDecl", decl.type)
            assert.equal("BinaryExpr", value.type)
        end)

        it("parses a string literal initialiser", function()
            local ast = parse('private msg = "hello"')
            local decl = ast.body[1] --[[@as VariableDecl]]
            local lit = decl.value --[[@as LiteralExpr]]
            assert.equal("VariableDecl", decl.type)
            assert.equal("LiteralExpr", lit.type)
            assert.equal("string", lit.kind)
            assert.equal("hello", lit.value)
        end)

        it("parses an identifier reference in an expression", function()
            local ast = parse("private x = 1\nprivate y = x")
            local y = ast.body[2] --[[@as VariableDecl]]
            local ident = y.value --[[@as IdentifierExpr]]
            assert.equal("IdentifierExpr", ident.type)
            assert.equal("x", ident.name)
        end)

        it("parses an empty program", function()
            local ast = parse("")
            assert.equal("Program", ast.type)
            assert.equal(0, #ast.body)
        end)
    end)

    describe("number literals", function()
        it("marks a fractional number literal as a float", function()
            local decl = parse("private x = 3.5").body[1] --[[@as VariableDecl]]
            local lit = decl.value --[[@as LiteralExpr]]
            assert.equal("number", lit.kind)
            assert.equal("float", lit.numeric)
            assert.equal(3.5, lit.value)
        end)

        it("marks an integer number literal as an int", function()
            local decl = parse("private x = 42").body[1] --[[@as VariableDecl]]
            local lit = decl.value --[[@as LiteralExpr]]
            assert.equal("int", lit.numeric)
        end)

        it("rejects a type annotation — the language is untyped", function()
            local ok, err = pcall(function() parse("private x: int = 1") end)
            assert.is_false(ok)
            assert.equal(Error.Type.UNEXPECTED_TOKEN, (err --[[@as Error]]).type)
        end)
    end)

    describe("constructor", function()
        it("parses a constructor with parameters", function()
            local c = parse("constructor(x, y) { .x = x }").body[1] --[[@as ConstructorDecl]]
            assert.equal("ConstructorDecl", c.type)
            assert.same({ "x", "y" }, c.params)
            local stmt = c.body[1]
            assert(stmt)
            assert.equal("FieldAssign", stmt.type)
        end)

        it("parses an empty constructor", function()
            local c = parse("constructor() {}").body[1] --[[@as ConstructorDecl]]
            assert.equal("ConstructorDecl", c.type)
            assert.equal(0, #c.params)
            assert.equal(0, #c.body)
        end)

        it("rejects a typed constructor parameter — the language is untyped", function()
            local ok, err = pcall(function() parse("constructor(x: int) { .x = x }") end)
            assert.is_false(ok)
            assert.equal(Error.Type.SYNTAX_ERROR, (err --[[@as Error]]).type)
        end)
    end)

    describe("field access", function()
        local function value_of(src)
            local decl = parse("private x = " .. src).body[1] --[[@as VariableDecl]]
            return decl.value
        end

        it("parses 'p.x' as a MemberExpr", function()
            local m = value_of("p.x") --[[@as MemberExpr]]
            assert.equal("MemberExpr", m.type)
            assert.equal("x", m.field)
            assert.equal("IdentifierExpr", m.object.type)
            local obj = m.object --[[@as IdentifierExpr]]
            assert.equal("p", obj.name)
        end)

        it("parses a leading-dot '.x' as a MemberExpr over the implicit receiver", function()
            local m = value_of(".x") --[[@as MemberExpr]]
            assert.equal("MemberExpr", m.type)
            assert.equal("x", m.field)
            assert.equal("SelfExpr", m.object.type)
        end)

        it("parses a leading-dot field assignment '.x = 3' as a FieldAssign", function()
            local s = parse(".x = 3").body[1] --[[@as FieldAssign]]
            assert.equal("FieldAssign", s.type)
            assert.equal("MemberExpr", s.target.type)
            assert.equal("SelfExpr", s.target.object.type)
            assert.equal("x", s.target.field)
        end)

        it("parses bare 'self' as a SelfExpr value", function()
            local e = value_of("self") --[[@as SelfExpr]]
            assert.equal("SelfExpr", e.type)
        end)

        it("parses 'self.x' to the same AST as '.x' (MemberExpr over SelfExpr)", function()
            local m = value_of("self.x") --[[@as MemberExpr]]
            assert.equal("MemberExpr", m.type)
            assert.equal("x", m.field)
            assert.equal("SelfExpr", m.object.type)
        end)

        it("parses 'self' passed as a call argument", function()
            local c = value_of("f(self)") --[[@as CallExpr]]
            assert.equal("CallExpr", c.type)
            local arg = c.args[1]
            assert(arg)
            assert.equal("SelfExpr", arg.type)
        end)

        it("treats a '.field' beginning a new line as a new statement, not a chain", function()
            -- `f()` then a newline `.x = 1` must not parse as `f().x` — the dot
            -- starts a fresh leading-dot statement.
            local body = parse("f()\n.x = 1").body
            assert.equal(2, #body)
            local first = body[1]
            local second = body[2] --[[@as FieldAssign]]
            assert(first)
            assert.equal("ExpressionStmt", first.type)
            assert.equal("FieldAssign", second.type)
            assert.equal("SelfExpr", second.target.object.type)
        end)

        it("parses chained access 'p.x.y' left-associatively", function()
            local m = value_of("p.x.y") --[[@as MemberExpr]]
            assert.equal("y", m.field)
            assert.equal("MemberExpr", m.object.type)
            local obj = m.object --[[@as MemberExpr]]
            assert.equal("x", obj.field)
        end)

        it("parses a method call 'p.m()' as a CallExpr over a MemberExpr", function()
            local c = value_of("p.m()") --[[@as CallExpr]]
            assert.equal("CallExpr", c.type)
            assert.equal("MemberExpr", c.callee.type)
            local callee = c.callee --[[@as MemberExpr]]
            assert.equal("m", callee.field)
        end)

        it("parses a field assignment as a FieldAssign statement", function()
            local s = parse("p.x = 3").body[1] --[[@as FieldAssign]]
            assert.equal("FieldAssign", s.type)
            assert.equal("MemberExpr", s.target.type)
            assert.equal("x", s.target.field)
            assert.equal("LiteralExpr", s.value.type)
        end)

        it("desugars a compound field assignment 'p.x += 1'", function()
            local s = parse("p.x += 1").body[1] --[[@as FieldAssign]]
            assert.equal("FieldAssign", s.type)
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", v.type)
            assert.equal("PLUS", v.op)
            assert.equal("MemberExpr", v.left.type)
        end)

        it("errors on a missing field name after '.'", function()
            local ok, err = pcall(function() parse("private x = p.") end)
            assert.is_false(ok)
            assert.matches("Expected a field name", (err --[[@as Error]]).message)
        end)
    end)

    describe("boolean / unary / comparison / logical expressions", function()
        local function value_of(src)
            local decl = parse("private x = " .. src).body[1] --[[@as VariableDecl]]
            return decl.value
        end

        it("parses 'true' as a boolean literal", function()
            local lit = value_of("true") --[[@as LiteralExpr]]
            assert.equal("LiteralExpr", lit.type)
            assert.equal("boolean", lit.kind)
            assert.equal(true, lit.value)
        end)

        it("parses 'false' as a boolean literal", function()
            local lit = value_of("false") --[[@as LiteralExpr]]
            assert.equal("boolean", lit.kind)
            assert.equal(false, lit.value)
        end)

        it("parses 'not a' as a UnaryExpr", function()
            local u = value_of("not a") --[[@as UnaryExpr]]
            assert.equal("UnaryExpr", u.type)
            assert.equal("NOT", u.op)
            assert.equal("IdentifierExpr", u.operand.type)
        end)

        local comparisons = {
            { "a == b", "EQ" },
            { "a != b", "NEQ" },
            { "a < b", "LESS" },
            { "a <= b", "LESS_EQUAL" },
            { "a > b", "GREATER" },
            { "a >= b", "GREATER_EQUAL" },
        }
        for _, case in ipairs(comparisons) do
            it("parses '" .. case[1] .. "' as BinaryExpr " .. case[2], function()
                local b = value_of(case[1]) --[[@as BinaryExpr]]
                assert.equal("BinaryExpr", b.type)
                assert.equal(case[2], b.op)
            end)
        end

        local arithmetic = {
            { "a / b", "DIVIDE" },
            { "a % b", "MODULO" },
            { "a ^ b", "POWER" },
            { "a ++ b", "CONCAT" },
        }
        for _, case in ipairs(arithmetic) do
            it("parses '" .. case[1] .. "' as BinaryExpr " .. case[2], function()
                local b = value_of(case[1]) --[[@as BinaryExpr]]
                assert.equal("BinaryExpr", b.type)
                assert.equal(case[2], b.op)
            end)
        end

        it("binds '/' at the multiplicative level (tighter than '+')", function()
            -- a + b / c  ->  a + (b / c)
            local top = value_of("a + b / c") --[[@as BinaryExpr]]
            assert.equal("PLUS", top.op)
            assert.equal("BinaryExpr", top.right.type)
            local right = top.right --[[@as BinaryExpr]]
            assert.equal("DIVIDE", right.op)
        end)

        it("binds '^' tighter than '*'", function()
            -- a * b ^ c  ->  a * (b ^ c)
            local top = value_of("a * b ^ c") --[[@as BinaryExpr]]
            assert.equal("MULTIPLY", top.op)
            assert.equal("BinaryExpr", top.right.type)
            local right = top.right --[[@as BinaryExpr]]
            assert.equal("POWER", right.op)
        end)

        it("parses 'a and b' as BinaryExpr AND", function()
            local b = value_of("a and b") --[[@as BinaryExpr]]
            assert.equal("AND", b.op)
        end)

        it("parses 'a or b' as BinaryExpr OR", function()
            local b = value_of("a or b") --[[@as BinaryExpr]]
            assert.equal("OR", b.op)
        end)

        it("binds 'and' tighter than 'or'", function()
            -- a or b and c  ->  a or (b and c)
            local top = value_of("a or b and c") --[[@as BinaryExpr]]
            assert.equal("OR", top.op)
            assert.equal("BinaryExpr", top.right.type)
            local right = top.right --[[@as BinaryExpr]]
            assert.equal("AND", right.op)
        end)

        it("binds arithmetic tighter than comparison", function()
            -- a + b == c  ->  (a + b) == c
            local top = value_of("a + b == c") --[[@as BinaryExpr]]
            assert.equal("EQ", top.op)
            assert.equal("BinaryExpr", top.left.type)
            local left = top.left --[[@as BinaryExpr]]
            assert.equal("PLUS", left.op)
        end)

        it("binds unary 'not' tighter than comparison (Lua semantics)", function()
            -- not a == b  ->  (not a) == b
            local top = value_of("not a == b") --[[@as BinaryExpr]]
            assert.equal("EQ", top.op)
            assert.equal("UnaryExpr", top.left.type)
        end)
    end)

    describe("control-flow statements", function()
        it("parses an if statement into a single clause", function()
            local s = parse("if a { x = 1 }").body[1] --[[@as IfStmt]]
            assert.equal("IfStmt", s.type)
            assert.equal(1, #s.clauses)
            local clause = s.clauses[1]
            assert(clause)
            assert.equal("IdentifierExpr", clause.condition.type)
            assert.equal(1, #clause.body)
            assert.is_nil(s.else_body)
        end)

        it("parses if / else if / else", function()
            local s = parse("if a { x = 1 } else if b { x = 2 } else { x = 3 }").body[1] --[[@as IfStmt]]
            assert.equal(2, #s.clauses)
            local clause = s.clauses[2]
            assert(clause)
            assert.equal("IdentifierExpr", clause.condition.type)
            assert.is_table(s.else_body)
            assert.equal(1, #s.else_body)
        end)

        it("parses a plain else (no else-if)", function()
            local s = parse("if a { x = 1 } else { x = 2 }").body[1] --[[@as IfStmt]]
            assert.equal(1, #s.clauses)
            assert.equal(1, #s.else_body)
        end)

        it("parses a while loop", function()
            local s = parse("while a { x = 1 }").body[1] --[[@as WhileStmt]]
            assert.equal("WhileStmt", s.type)
            assert.equal("IdentifierExpr", s.condition.type)
            assert.equal(1, #s.body)
        end)

        it("parses an infinite loop", function()
            local s = parse("loop { x = 1 }").body[1] --[[@as LoopStmt]]
            assert.equal("LoopStmt", s.type)
            assert.equal(1, #s.body)
        end)

        it("parses break inside a loop", function()
            local s = parse("loop { break }").body[1] --[[@as LoopStmt]]
            local stmt = s.body[1]
            assert(stmt)
            assert.equal("BreakStmt", stmt.type)
        end)

        it("parses a C-style for without parens", function()
            local s = parse("for i = 0; i < n; i = i + 1 { x = 1 }").body[1] --[[@as ForStmt]]
            assert.equal("ForStmt", s.type)
            local init = s.init
            assert(init)
            assert.equal("VariableDecl", init.type)
            assert.equal("i", init.name)
            local condition = s.condition --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", condition.type)
            assert.equal("LESS", condition.op)
            local step = s.step
            assert(step)
            assert.equal("VariableDecl", step.type)
            assert.equal(1, #s.body)
        end)

        it("allows empty for clauses", function()
            local s = parse("for ; ; { break }").body[1] --[[@as ForStmt]]
            assert.equal("ForStmt", s.type)
            assert.is_nil(s.init)
            assert.is_nil(s.condition)
            assert.is_nil(s.step)
        end)

        it("accepts compound assignment as the for step", function()
            local s = parse("for i = 0; i < n; i += 1 { x = 1 }").body[1] --[[@as ForStmt]]
            local step = s.step --[[@as VariableDecl]]
            assert.equal("VariableDecl", step.type)
            local value = step.value --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", value.type)
            assert.equal("PLUS", value.op)
        end)
    end)

    describe("compound assignment", function()
        it("desugars 'i += 1' to 'i = i + 1'", function()
            local s = parse("i += 1").body[1] --[[@as VariableDecl]]
            assert.equal("VariableDecl", s.type)
            assert.equal("i", s.name)
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", v.type)
            assert.equal("PLUS", v.op)
            assert.equal("IdentifierExpr", v.left.type)
            local left = v.left --[[@as IdentifierExpr]]
            assert.equal("i", left.name)
        end)

        it("desugars '*=' to a MULTIPLY reassignment", function()
            local s = parse("i *= 2").body[1] --[[@as VariableDecl]]
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("MULTIPLY", v.op)
        end)

        it("desugars '-=' to a MINUS reassignment", function()
            local s = parse("i -= 2").body[1] --[[@as VariableDecl]]
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("MINUS", v.op)
        end)

        it("desugars '/=' to a DIVIDE reassignment", function()
            local s = parse("i /= 2").body[1] --[[@as VariableDecl]]
            local v = s.value --[[@as BinaryExpr]]
            assert.equal("DIVIDE", v.op)
        end)
    end)

    describe("error paths", function()
        it("throws SYNTAX_ERROR for a missing identifier after 'private'", function()
            local ok, err = pcall(function() parse("private = 5") end)
            assert.is_false(ok)
            local e = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, e.type)
            assert.matches("Expected property name after 'private'", e.message)
        end)

        it("throws SYNTAX_ERROR for an unclosed parenthesis", function()
            local ok, err = pcall(function() parse("private x = (1 + 2") end)
            assert.is_false(ok)
            local e = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, e.type)
        end)

        it("throws UNEXPECTED_TOKEN for '=' in statement position", function()
            local ok, err = pcall(function() parse("= 5") end)
            assert.is_false(ok)
            -- ASSIGN is a keyword-only token; the dispatcher rejects it
            local e = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_TOKEN, e.type)
        end)

        it("throws on an empty grouped expression '()'", function()
            local ok, _err = pcall(function() parse("private x = ()") end)
            assert.is_false(ok)
        end)

        it("attaches source position to SYNTAX_ERROR from _consume", function()
            local ok, err = pcall(function() parse("private 42") end)
            assert.is_false(ok)
            local e = err --[[@as Error]]
            assert.equal(Error.Type.SYNTAX_ERROR, e.type)
            assert.is_number(e.line)
            assert.is_number(e.col)
        end)

        it("throws UNEXPECTED_EOF when input ends mid-expression", function()
            local ok, err = pcall(function() parse("private x = 1 +") end)
            assert.is_false(ok)
            -- parser runs out of tokens inside _primary
            local e = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_EOF, e.type)
        end)
    end)

    describe("imports", function()
        it("parses a single-segment 'import Name' into an ImportDecl", function()
            local decl = parse("import Box").body[1] --[[@as ImportDecl]]
            assert.equal("ImportDecl", decl.type)
            assert.equal("Box", decl.name)
            assert.same({ "Box" }, decl.segments)
        end)

        it("parses a dotted 'import a.b.Class' path into segments", function()
            local decl = parse("import actors.enemy.Enemy").body[1] --[[@as ImportDecl]]
            assert.equal("ImportDecl", decl.type)
            -- The class name is the final segment.
            assert.equal("Enemy", decl.name)
            assert.same({ "actors", "enemy", "Enemy" }, decl.segments)
        end)

        it("requires a name after 'import'", function()
            local ok, err = pcall(function() parse("import 42") end)
            assert.is_false(ok)
            assert.equal(Error.Type.SYNTAX_ERROR, (err --[[@as Error]]).type)
        end)

        it("requires a name after a '.' in an import path", function()
            local ok, err = pcall(function() parse("import a.") end)
            assert.is_false(ok)
            assert.equal(Error.Type.SYNTAX_ERROR, (err --[[@as Error]]).type)
        end)
    end)
end)
