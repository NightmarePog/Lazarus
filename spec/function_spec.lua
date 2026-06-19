local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen   = require("backend")

local load_chunk = loadstring or load

local function parse(source)
    return Parser.new(Lexer.new(source):scan(), source):parse()
end

local function analyze(source)
    local ast = parse(source)
    Schematic.analyze(ast, source)
    return ast
end

local function optimize(source)
    local ast = analyze(source)
    return Optimizer.optimize(ast)
end

--- Run the full pipeline and return the generated Lua source string.
--- Header and footer are disabled so the assertions below see the bare body.
local function compile(source)
    local ast = Optimizer.optimize(analyze(source))
    return Codegen.new(ast):generate({ header = false, entry = false })
end

-- The constant class scaffold prefixing every member in `compile` output.
local SCAFFOLD = "local Main = {}"

--- Just the emitted member lines, with the constant scaffold stripped.
local function members(source)
    local out = compile(source)
    if out == SCAFFOLD then return "" end
    return out:sub(#SCAFFOLD + 3)
end

describe("Functions", function ()
    describe("parser", function ()
        it("parses a no-parameter function with a return", function ()
            local ast  = parse("fn f() { return 0 }")
            local decl = ast.body[1] --[[@as FunctionDecl]]
            assert.equal("FunctionDecl", decl.type)
            assert.equal("f", decl.name)
            assert.same({}, decl.params)
            assert.equal(1, #decl.body)
            assert.equal("ReturnStmt", decl.body[1].type)
        end)

        it("parses a parameter list", function ()
            local decl = parse("fn add(a, b) { return a + b }").body[1] --[[@as FunctionDecl]]
            assert.same({ "a", "b" }, decl.params)
        end)

        it("parses a bare return with no value", function ()
            local decl = parse("fn f() { return }").body[1] --[[@as FunctionDecl]]
            local ret  = decl.body[1] --[[@as ReturnStmt]]
            assert.equal("ReturnStmt", ret.type)
            assert.is_nil(ret.value)
        end)

        it("parses an empty body", function ()
            local decl = parse("fn noop() {}").body[1] --[[@as FunctionDecl]]
            assert.equal(0, #decl.body)
        end)

        it("errors on a missing '('", function ()
            local ok, err = pcall(parse, "fn f { return 0 }")
            assert.is_false(ok)
            assert.matches("Expected '%('", err.message)
        end)

        it("errors on an unterminated body", function ()
            local ok, err = pcall(parse, "fn f() { return 0")
            assert.is_false(ok)
            assert.matches("Expected '}'", err.message)
        end)
    end)

    describe("schematic", function ()
        it("accepts a parameter referenced in the body", function ()
            assert.has_no.errors(function () analyze("fn f(a) { return a }") end)
        end)

        it("accepts an outer constant referenced in the body", function ()
            assert.has_no.errors(function () analyze("private k = 2\nfn f() { return k }") end)
        end)

        it("accepts a recursive self-reference", function ()
            assert.has_no.errors(function () analyze("fn f() { return f }") end)
        end)

        it("rejects 'return' outside a function", function ()
            local ok, err = pcall(analyze, "return 0")
            assert.is_false(ok)
            assert.matches("'return' outside of a function", err.message)
        end)

        it("rejects 'return' that is not the last statement in a block", function ()
            local ok, err = pcall(analyze, "fn f() { return 0\nprivate x = 1 }")
            assert.is_false(ok)
            assert.matches("'return' must be the last statement", err.message)
        end)

        it("rejects a duplicate parameter", function ()
            local ok, err = pcall(analyze, "fn f(a, a) { return a }")
            assert.is_false(ok)
            assert.matches("Duplicate parameter 'a'", err.message)
        end)

        it("rejects an undeclared identifier in the body", function ()
            local ok, err = pcall(analyze, "fn f() { return nope }")
            assert.is_false(ok)
            assert.matches("Undeclared identifier 'nope'", err.message)
        end)

        it("does not leak a parameter into the outer scope", function ()
            local ok, err = pcall(analyze, "fn f(a) { return a }\nprivate x = a")
            assert.is_false(ok)
            assert.matches("Undeclared identifier 'a'", err.message)
        end)
    end)

    describe("optimizer", function ()
        it("folds a constant return expression", function ()
            local decl = optimize("fn f() { return 2 + 3 }").body[1] --[[@as FunctionDecl]]
            local ret  = decl.body[1] --[[@as ReturnStmt]]
            assert.equal("LiteralExpr", ret.value.type)
            assert.equal(5, ret.value.value)
        end)

        it("propagates an outer constant into the body", function ()
            local decl = optimize("private k = 2\nfn f() { return k + 1 }").body[2] --[[@as FunctionDecl]]
            local ret  = decl.body[1] --[[@as ReturnStmt]]
            assert.equal("LiteralExpr", ret.value.type)
            assert.equal(3, ret.value.value)
        end)

        it("does not fold a parameter that shadows an outer constant", function ()
            local decl = optimize("private x = 9\nfn f(x) { return x + 1 }").body[2] --[[@as FunctionDecl]]
            local ret  = decl.body[1] --[[@as ReturnStmt]]
            -- `x` is the parameter, not the constant, so the sum must not fold.
            assert.equal("BinaryExpr", ret.value.type)
        end)
    end)

    describe("codegen", function ()
        it("emits a no-parameter function as a static method", function ()
            assert.equal("function Main.f()\n    return 0\nend", members("fn f() { return 0 }"))
        end)

        it("emits a parameter list", function ()
            assert.equal("function Main.add(a, b)\n    return a + b\nend",
                members("fn add(a, b) { return a + b }"))
        end)

        it("emits an empty body", function ()
            assert.equal("function Main.noop()\nend", members("fn noop() {}"))
        end)

        it("emits a bare return", function ()
            assert.equal("function Main.f()\n    return\nend", members("fn f() { return }"))
        end)

        it("indents a nested function as a local function", function ()
            assert.equal(
                "function Main.outer()\n    local function inner()\n        return 1\n    end\nend",
                members("fn outer() { fn inner() { return 1 } }"))
        end)
    end)

    describe("output is valid Lua", function ()
        local cases = {
            "fn f() { return 0 }",
            "fn add(a, b) { return a + b }",
            "fn noop() {}",
            "fn f() { return }",
            "fn outer() { fn inner() { return 1 } }",
            "private k = 2\nfn f() { return k + 1 }",
        }
        for _, src in ipairs(cases) do
            it("loads: " .. src:gsub("\n", " "), function ()
                local chunk, err = load_chunk(compile(src))
                assert.is_function(chunk, err)
            end)
        end
    end)
end)

describe("Function calls", function ()
    describe("parser", function ()
        it("parses a call with no arguments", function ()
            local stmt = parse("f()").body[1] --[[@as ExpressionStmt]]
            assert.equal("ExpressionStmt", stmt.type)
            local call = stmt.expression --[[@as CallExpr]]
            assert.equal("CallExpr", call.type)
            assert.equal("IdentifierExpr", call.callee.type)
            assert.equal("f", call.callee.name)
            assert.equal(0, #call.args)
        end)

        it("parses a call with an argument list", function ()
            local call = parse("add(a, b)").body[1].expression --[[@as CallExpr]]
            assert.equal(2, #call.args)
            assert.equal("a", call.args[1].name)
            assert.equal("b", call.args[2].name)
        end)

        it("parses a call used as an argument", function ()
            local call = parse("f(g(x))").body[1].expression --[[@as CallExpr]]
            assert.equal(1, #call.args)
            assert.equal("CallExpr", call.args[1].type)
        end)

        it("parses chained calls", function ()
            local call = parse("g()()").body[1].expression --[[@as CallExpr]]
            assert.equal("CallExpr", call.type)
            assert.equal("CallExpr", call.callee.type)
        end)

        it("binds a call tighter than multiplication", function ()
            -- a * b(c)  ->  a * (b(c))
            local mul = parse("a * b(c)").body[1].expression --[[@as BinaryExpr]]
            assert.equal("BinaryExpr", mul.type)
            assert.equal("CallExpr", mul.right.type)
        end)

        it("errors on a missing ')' in an argument list", function ()
            local ok, err = pcall(parse, "f(a, b")
            assert.is_false(ok)
            assert.matches("Expected '%)'", err.message)
        end)
    end)

    describe("schematic", function ()
        it("accepts a call to a previously declared function", function ()
            assert.has_no.errors(function () analyze("fn f() { return 0 }\nf()") end)
        end)

        it("accepts a call inside a function body", function ()
            assert.has_no.errors(function ()
                analyze("fn id(a) { return a }\nfn use(a) { return id(a) }")
            end)
        end)

        it("rejects a call to an undeclared function", function ()
            local ok, err = pcall(analyze, "nope()")
            assert.is_false(ok)
            assert.matches("Undeclared identifier 'nope'", err.message)
        end)

        it("rejects an undeclared argument", function ()
            local ok, err = pcall(analyze, "fn f(a) { return a }\nf(missing)")
            assert.is_false(ok)
            assert.matches("Undeclared identifier 'missing'", err.message)
        end)

        it("still rejects a bare non-call expression statement", function ()
            local ok, err = pcall(analyze, "private x = 1\nx")
            assert.is_false(ok)
            assert.matches("Bare expressions are not valid statements", err.message)
        end)
    end)

    describe("optimizer", function ()
        it("propagates a constant into a call argument", function ()
            local call = optimize("private k = 2\nfn f(a) { return a }\nf(k + 1)").body[3].expression --[[@as CallExpr]]
            assert.equal("LiteralExpr", call.args[1].type)
            assert.equal(3, call.args[1].value)
        end)
    end)

    describe("codegen", function ()
        it("emits a no-argument call, qualifying the member callee", function ()
            assert.equal("function Main.f()\n    return 0\nend\nMain.f()",
                members("fn f() { return 0 }\nf()"))
        end)

        it("emits a call with arguments", function ()
            assert.equal("function Main.add(a, b)\n    return a + b\nend\nMain.add(1, 2)",
                members("fn add(a, b) { return a + b }\nadd(1, 2)"))
        end)
    end)

    describe("output is valid Lua", function ()
        local cases = {
            "fn f() { return 0 }\nf()",
            "fn add(a, b) { return a + b }\nadd(1, 2)",
            "fn id(a) { return a }\nfn use(a) { return id(a) }",
        }
        for _, src in ipairs(cases) do
            it("loads: " .. src:gsub("\n", " "), function ()
                local chunk, err = load_chunk(compile(src))
                assert.is_function(chunk, err)
            end)
        end
    end)
end)
