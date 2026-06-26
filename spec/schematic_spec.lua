local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Error = require("error")

local function analyze(source)
    Schematic.analyze(Parser.new(Lexer.new(source):scan(), source):parse(), source)
end

describe("Schematic", function()
    describe("valid programs", function()
        it("accepts a static member and a later reference to it", function()
            assert.has_no.errors(
                function() analyze("private static x = 1\nprivate static y = x") end
            )
        end)

        it("accepts an immutable static member referenced in a later expression", function()
            assert.has_no.errors(
                function() analyze("private static foo = 3\nprivate static bar = foo + 1") end
            )
        end)

        it("accepts reassignment of a mutable binding inside a function", function()
            assert.has_no.errors(
                function() analyze("static f() { mut n = 0\nn = 1\nreturn n }") end
            )
        end)
    end)

    describe("mutability", function()
        it("rejects reassignment of an immutable binding", function()
            local ok, raw_err = pcall(analyze, "static f() { a = 1\na = 2\nreturn a }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Cannot assign to immutable binding 'a'", err.message)
        end)

        it("rejects reassignment of a function parameter", function()
            local ok, raw_err = pcall(analyze, "static f(a) { a = 2\nreturn a }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.matches("Cannot assign to immutable binding 'a'", err.message)
        end)
    end)

    describe("visibility", function()
        it("rejects a top-level binding with no visibility modifier", function()
            local ok, raw_err = pcall(analyze, "x = 1")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("must declare visibility", err.message)
        end)

        it("accepts a bare binding inside a function", function()
            assert.has_no.errors(function() analyze("static f() { a = 1\nreturn a }") end)
        end)
    end)

    describe("duplicate declarations", function()
        it("rejects a redeclared static member with SEMANTIC_ERROR and a position", function()
            local ok, raw_err = pcall(analyze, "private static x = 1\nprivate static x = 2")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Duplicate declaration 'x'", err.message)
            assert.equal(2, err.line)
            assert.is_number(err.col)
        end)

        it("rejects a redeclared instance property", function()
            local ok, err = pcall(analyze, "private x\nprivate x")
            assert.is_false(ok)
            assert.matches("Duplicate declaration 'x'", (err --[[@as Error]]).message)
        end)
    end)

    describe("undeclared identifiers", function()
        it("rejects a reference to an unknown name with a source position", function()
            local ok, raw_err = pcall(analyze, "private static y = nope")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Undeclared identifier 'nope'", err.message)
            assert.equal(1, err.line)
            assert.equal(20, err.col)
        end)

        it("rejects self-reference in an initialiser", function()
            local ok, raw_err = pcall(analyze, "private static x = x")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
        end)
    end)

    describe("control flow", function()
        it("accepts if / else if / else referencing visible names", function()
            assert.has_no.errors(
                function()
                    analyze("static f(a, b) { if a { x = 1 } else if b { x = 2 } else { x = 3 } }")
                end
            )
        end)

        it("accepts a while loop mutating an outer mutable binding", function()
            assert.has_no.errors(
                function() analyze("static f(n) { mut i = 0\n while i < n { i = i + 1 } }") end
            )
        end)

        it("accepts an infinite loop containing break", function()
            assert.has_no.errors(function() analyze("static f() { loop { break } }") end)
        end)

        it("accepts a C-style for whose step mutates the loop variable", function()
            -- the loop variable `i` is a fresh, implicitly-mutable binding, so the
            -- `i += 1` step must be legal even though it was not declared `mut`.
            assert.has_no.errors(
                function() analyze("static f(n) { for i = 0; i < n; i += 1 { x = i } }") end
            )
        end)

        it("rejects an undeclared identifier in a condition", function()
            local ok, raw_err = pcall(analyze, "static f() { while nope { x = 1 } }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Undeclared identifier 'nope'", err.message)
        end)

        it("does not leak a binding declared inside an if body", function()
            local ok, raw_err = pcall(analyze, "static f(a) { if a { y = 1 }\n return y }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.matches("Undeclared identifier 'y'", err.message)
        end)

        it("rejects break outside any loop", function()
            local ok, raw_err = pcall(analyze, "static f() { break }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("'break' outside", err.message)
        end)

        it("rejects break that is not the last statement in its block", function()
            local ok, raw_err = pcall(analyze, "static f() { loop { break\n x = 1 } }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.matches("'break' must be the last statement", err.message)
        end)

        it("checks operands of a unary expression", function()
            local ok, raw_err = pcall(analyze, "private static x = not nope")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.matches("Undeclared identifier 'nope'", err.message)
        end)

        it("accepts a unary expression over a visible name", function()
            assert.has_no.errors(
                function() analyze("private static p = true\nprivate static q = not p") end
            )
        end)
    end)

    describe("bare expression statements", function()
        it("rejects a bare expression as a statement", function()
            local ok, raw_err = pcall(analyze, "private static x = 1\nx + x")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Bare expressions are not valid statements", err.message)
        end)
    end)

    describe("constructor", function()
        it("accepts a constructor whose body sets declared properties from params", function()
            assert.has_no.errors(
                function() analyze("private x\nprivate y\nconstructor(x, y) { .x = x\n.y = y }") end
            )
        end)

        it("accepts construction of the class by name", function()
            assert.has_no.errors(
                function()
                    analyze(
                        "private x\nconstructor(x) { .x = x }\nstatic main() { mut p = Main(5)\nreturn p.x }"
                    )
                end
            )
        end)

        it("rejects a constructor nested inside a function", function()
            local ok, err = pcall(analyze, "static f() { constructor() {} }")
            assert.is_false(ok)
            assert.matches("must be at the top level", (err --[[@as Error]]).message)
        end)

        it("rejects a return inside a constructor", function()
            local ok, err = pcall(analyze, "constructor() { return 1 }")
            assert.is_false(ok)
            assert.matches(
                "'return' is not allowed in a constructor",
                (err --[[@as Error]]).message
            )
        end)
    end)

    describe("field access", function()
        it("accepts field read and assignment on a declared object", function()
            assert.has_no.errors(function() analyze("static f(p) { p.x = 1\nreturn p.x }") end)
        end)

        it("rejects field assignment on an undeclared object", function()
            local ok, err = pcall(analyze, "static f() { nope.x = 1 }")
            assert.is_false(ok)
            assert.matches("Undeclared identifier 'nope'", (err --[[@as Error]]).message)
        end)
    end)

    describe("instance fields (.field on the implicit receiver)", function()
        it("accepts a declared property read and written via .field in a method", function()
            assert.has_no.errors(
                function() analyze('private name\nset_name() { .name = "x"\nreturn .name }') end
            )
        end)

        it("lets a constructor param and a property share a name", function()
            assert.has_no.errors(
                function() analyze("private balance\nconstructor(balance) { .balance = balance }") end
            )
        end)

        it("rejects an undeclared instance field", function()
            local ok, raw_err = pcall(analyze, "deposit() { .bogus = 1 }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("Unknown instance member '.bogus'", err.message)
        end)

        it("rejects .field in a static method (no receiver)", function()
            local ok, raw_err = pcall(analyze, "private x\nstatic helper() { return .x }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("no receiver", err.message)
        end)

        it("allows calling an instance method on the receiver via .method()", function()
            assert.has_no.errors(
                function()
                    analyze(
                        "private label\ndescribe() { return .label }\nbuild() { return .describe() }"
                    )
                end
            )
        end)
    end)

    describe("methods", function()
        it("accepts an instance method using its receiver's declared fields", function()
            assert.has_no.errors(
                function() analyze('private name\ngreet() { .name = "x"\nreturn .name }') end
            )
        end)

        it("accepts 'self' as a value passed to a helper", function()
            -- `self` is a real receiver value: it can be passed around (closing
            -- the receiver gap), and `self.x` is equivalent to `.x`.
            assert.has_no.errors(
                function()
                    analyze("private x\nstatic id(p) { return p }\nwrap() { return id(self) }")
                end
            )
        end)

        it("treats self.x and .x as equivalent", function()
            assert.has_no.errors(
                function() analyze('private name\ngreet() { self.name = "x"\nreturn .name }') end
            )
        end)

        it("rejects a bare 'self' outside an instance context (no receiver)", function()
            local ok, raw_err = pcall(analyze, "static helper() { return self }")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("no receiver", err.message)
        end)

        it("rejects an undeclared field via self.bogus, like .bogus", function()
            local ok, err = pcall(analyze, "deposit() { self.bogus = 1 }")
            assert.is_false(ok)
            assert.matches("Unknown instance member '.bogus'", (err --[[@as Error]]).message)
        end)
    end)

    describe("callability", function()
        it("rejects calling a non-function value binding", function()
            local ok, err = pcall(analyze, "static f() { mut a = 0\na = a(a) }")
            assert.is_false(ok)
            assert.equal(Error.Type.NOT_CALLABLE, (err --[[@as Error]]).type)
            assert.matches("not callable", (err --[[@as Error]]).message)
        end)

        it("accepts calling a declared function", function()
            assert.has_no.errors(
                function() analyze("static g() { return 0 }\nstatic f() { return g() }") end
            )
        end)

        it("allows calling a parameter that might hold a function", function()
            assert.has_no.errors(function() analyze("static f(cb) { return cb() }") end)
        end)
    end)

    describe("casing", function()
        it("accepts snake_case values", function()
            assert.has_no.errors(
                function() analyze("private static my_var = 1\nstatic do_thing(a_b) { return a_b }") end
            )
        end)

        it("rejects a non-snake_case property name", function()
            local ok, raw_err = pcall(analyze, "private myVar")
            assert.is_false(ok)
            local err = raw_err --[[@as Error]]
            assert.equal(Error.Type.SEMANTIC_ERROR, err.type)
            assert.matches("must be snake_case", err.message)
        end)

        it("rejects a non-snake_case static member name", function()
            local ok, err = pcall(analyze, "private static myVar = 1")
            assert.is_false(ok)
            assert.matches("must be snake_case", (err --[[@as Error]]).message)
        end)

        it("rejects a non-snake_case function name", function()
            local ok, err = pcall(analyze, "static DoThing() { return 1 }")
            assert.is_false(ok)
            assert.matches("must be snake_case", (err --[[@as Error]]).message)
        end)

        it("rejects a non-snake_case parameter name", function()
            local ok, err = pcall(analyze, "static f(myArg) { return myArg }")
            assert.is_false(ok)
            assert.matches("must be snake_case", (err --[[@as Error]]).message)
        end)

        it("rejects a non-snake_case loop variable", function()
            local ok, err =
                pcall(analyze, "static f() { for Idx = 0; Idx < 3; Idx += 1 { x = Idx } }")
            assert.is_false(ok)
            assert.matches("must be snake_case", (err --[[@as Error]]).message)
        end)
    end)
end)
