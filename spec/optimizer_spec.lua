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
    end)

    describe("constant propagation", function ()
        it("substitutes a folded constant into a later expression", function ()
            local ast = optimize("constant foo = 3 + 2\nprivate x = foo + 1")
            local v = value_of(ast, 2)
            assert.equal("LiteralExpr", v.type)
            assert.equal(6, v.value)
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
            local ast = optimize("private a = 1\nprivate b = a + 0")
            local v = value_of(ast, 2)
            assert.equal("BinaryExpr", v.type)
        end)
    end)
end)
