local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Optimizer = require("frontend.optimizer")

local function optimize(source)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()
    return Optimizer.optimize(ast)
end

--- Fetch the initialiser expression of the i-th top-level declaration.
local function value_of(ast, i)
    return ast.body[i].value
end

describe("Optimizer", function ()
    describe("constant folding", function ()
        it("folds a numeric binary expression to a literal", function ()
            local ast = optimize("private x = 3 + 2")
            local v = value_of(ast, 1)
            assert.equal("LiteralExpr", v.type)
            assert.equal(5, v.value)
        end)

        it("folds a nested numeric expression", function ()
            local ast = optimize("private x = 5 + 5 - 2 * (2 + 1)")
            local v = value_of(ast, 1)
            assert.equal("LiteralExpr", v.type)
            assert.equal(4, v.value)
        end)

        it("folds division", function ()
            local v = value_of(optimize("private x = 9 / 2"), 1)
            assert.equal("LiteralExpr", v.type)
            assert.equal(4.5, v.value)
        end)

        it("folds modulo using the Lua 5.0 definition", function ()
            local v = value_of(optimize("private x = 10 % 3"), 1)
            assert.equal("LiteralExpr", v.type)
            assert.equal(1, v.value)
        end)

        it("folds exponentiation", function ()
            local v = value_of(optimize("private x = 2 ^ 3"), 1)
            assert.equal("LiteralExpr", v.type)
            assert.equal(8, v.value)
        end)

        it("does NOT fold division by zero (inf has no Lua literal)", function ()
            local v = value_of(optimize("private x = 1 / 0"), 1)
            assert.equal("BinaryExpr", v.type)
        end)
    end)

    describe("constant propagation", function ()
        it("substitutes a folded immutable binding into a later expression", function ()
            local ast = optimize("private foo = 3 + 2\nprivate x = foo + 1")
            local v = value_of(ast, 2)
            assert.equal("LiteralExpr", v.type)
            assert.equal(6, v.value)
        end)

        it("does NOT propagate a mutable binding", function ()
            local ast = optimize("private mut foo = 5\nprivate x = foo + 1")
            local v = value_of(ast, 2)
            -- `foo` may change, so its reference must survive.
            assert.equal("BinaryExpr", v.type)
        end)
    end)

    describe("control flow", function ()
        it("propagates a constant into an if condition", function ()
            local ast = optimize("private k = 5\nif k { x = 1 }")
            local cond = ast.body[2].clauses[1].condition
            assert.equal("LiteralExpr", cond.type)
            assert.equal(5, cond.value)
        end)

        it("folds an arithmetic while condition", function ()
            local ast = optimize("private a = 1\nwhile 2 + 3 { x = a }")
            local cond = ast.body[2].condition
            assert.equal("LiteralExpr", cond.type)
            assert.equal(5, cond.value)
        end)

        it("folds inside a loop body", function ()
            local ast = optimize("private k = 4\nloop { y = k + 1\nbreak }")
            local y = ast.body[2].body[1].value
            assert.equal("LiteralExpr", y.type)
            assert.equal(5, y.value)
        end)

        it("does not treat the for loop variable as a constant", function ()
            local ast = optimize("private n = 10\nfor i = 0; i < n; i += 1 { z = 2 * 4 }")
            local for_stmt = ast.body[2]
            -- `i` is mutable across iterations, so it must stay an identifier;
            -- `n` is an immutable literal and folds in.
            assert.equal("BinaryExpr", for_stmt.condition.type)
            assert.equal("IdentifierExpr", for_stmt.condition.left.type)
            assert.equal("LiteralExpr", for_stmt.condition.right.type)
            assert.equal(10, for_stmt.condition.right.value)
            -- the body still folds its own constant expressions
            assert.equal(8, for_stmt.body[1].value.value)
        end)

        it("propagates a constant into a unary operand", function ()
            local ast = optimize("private p = true\nprivate q = not p")
            local q = ast.body[2].value
            assert.equal("UnaryExpr", q.type)
            assert.equal("LiteralExpr", q.operand.type)
            assert.equal(true, q.operand.value)
        end)
    end)

    describe("soundness", function ()
        it("does NOT fold `s * 0` when `s` is not a numeric literal", function ()
            -- `"hi" * 0` is a runtime error in Lua; folding it to 0 would
            -- change observable behaviour, so the BinaryExpr must survive.
            local ast = optimize('private s = "hi"\nprivate y = s * 0')
            local v = value_of(ast, 2)
            assert.equal("BinaryExpr", v.type)
            assert.equal("MULTIPLY", v.op)
        end)

        it("does NOT simplify `x + 0` for an identifier operand", function ()
            -- `a` is mutable, so it is not propagated and stays an identifier.
            local ast = optimize("private mut a = 1\nprivate b = a + 0")
            local v = value_of(ast, 2)
            assert.equal("BinaryExpr", v.type)
        end)
    end)
end)
