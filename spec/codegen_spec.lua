local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen = require("backend")

local load_chunk = loadstring or load

--- Run the front end and optimizer, returning the AST ready for codegen.
local function build(source)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()
    Schematic.analyze(ast, source)
    return Optimizer.optimize(ast)
end

--- Generated Lua body only — header and footer disabled so the assertions
--- below see the bare statement output.
local function compile(source)
    return Codegen.new(build(source)):generate({ header = false, entry = false })
end

--- Full program output, including the banner header and `main()` footer.
local function compile_program(source) return Codegen.new(build(source)):generate() end

-- The constant class scaffold that precedes every member in `compile` output
-- (a file lowers to a plain class table named `Main` by default).
local SCAFFOLD = "local Main = {}"

--- Just the emitted member lines, with the constant scaffold stripped, for
--- focused assertions on what a top-level statement lowers to.
local function members(source)
    local out = compile(source)
    if out == SCAFFOLD then return "" end
    return out:sub(#SCAFFOLD + 3) -- skip the scaffold and its trailing "\n\n"
end

describe("Codegen", function()
    describe("emission", function()
        it(
            "emits a static member as a class member",
            function() assert.equal("Main.x = 5", members("private static x = 5")) end
        )

        it(
            "emits a valueless mutable static member as a nil member",
            function() assert.equal("Main.x = nil", members("private static mut x")) end
        )

        it(
            "folds and emits an immutable static member initialiser",
            function() assert.equal("Main.foo = 5", members("private static foo = 3 + 2")) end
        )

        it(
            "emits a public static member too (export is a Phase 6 concern)",
            function() assert.equal("Main.x = 5", members("public static x = 5")) end
        )

        it(
            "emits a method with locals and a reassignment",
            function()
                assert.equal(
                    "function Main.f()\n    local n = 0\n    n = 1\n    return n\nend",
                    members("static f() { mut n = 0\nn = 1\nreturn n }")
                )
            end
        )

        it("qualifies static-member references and parenthesises nested binary operands", function()
            -- `a` is a mutable static member, so it is not propagated/folded;
            -- references to it inside `b` are qualified as `Main.a`.
            assert.equal(
                "Main.a = 1\nMain.b = (Main.a + 1) * 2",
                members("private static mut a = 1\nprivate static b = (a + 1) * 2")
            )
        end)

        it(
            "emits string literals via %q",
            function() assert.equal('Main.s = "hi"', members('private static s = "hi"')) end
        )

        it("emits an instance property with a default into C.new, not as a member", function()
            -- A non-static `private x = …` is an instance property: it produces no
            -- `Main.x` member; its default is assigned on `self` in the constructor.
            assert.equal(
                "function Main.new()\n    local self = {}\n    self.x = 5\n    return self\nend",
                members("private x = 5\nconstructor() {}")
            )
        end)
    end)

    describe("control flow", function()
        it("emits if / elseif / else", function()
            local out =
                compile("static f(a, b) { if a { x = 1 } else if b { x = 2 } else { x = 3 } }")
            assert.matches("if a then", out)
            assert.matches("elseif b then", out)
            assert.matches("\n    else\n", out)
            assert.matches("\n    end", out)
        end)

        it("emits a while loop", function()
            local out = compile("static f(n) { mut i = 0\nwhile i < n { i = i + 1 } }")
            assert.matches("while i < n do", out)
        end)

        it("emits loop as 'while true'", function()
            local out = compile("static f() { loop { break } }")
            assert.matches("while true do", out)
            assert.matches("break", out)
        end)

        it("lowers a C-style for to a do / while block", function()
            local out = compile("static f(n) { for i = 0; i < n; i += 1 { x = i } }")
            assert.matches("do", out)
            assert.matches("local i = 0", out)
            assert.matches("while i < n do", out)
            assert.matches("i = i %+ 1", out)
        end)

        it(
            "emits comparison operators",
            function() assert.matches("a == b", compile("static f(a, b) { if a == b { x = 1 } }")) end
        )

        it(
            "emits != as ~=",
            function() assert.matches("a ~= b", compile("static f(a, b) { if a != b { x = 1 } }")) end
        )

        it("emits and / or", function()
            local out = compile("static f(a, b) { if a and b { x = 1 } }")
            assert.matches("a and b", out)
        end)

        it("emits boolean literals", function()
            local out = compile("static f() { mut t = true\nt = false }")
            assert.matches("local t = true", out)
            assert.matches("t = false", out)
        end)

        it(
            "emits unary not",
            function() assert.matches("not a", compile("static f(a) { if not a { x = 1 } }")) end
        )

        it(
            "parenthesises a parenthesised binary operand of not",
            function()
                assert.matches(
                    "not %(a == b%)",
                    compile("static f(a, b) { if not (a == b) { x = 1 } }")
                )
            end
        )
    end)

    describe("header", function()
        it("emits a banner comment at the top by default", function()
            local out = compile_program("constructor() {}")
            assert.matches("^%-%-%-+\n%-%- Generated by the Lazarus compiler", out)
            assert.matches("Target runtime: Lua 5%.0", out)
        end)

        it("places the class body after the header", function()
            local out = compile_program("constructor() {}")
            assert.matches("\n\nlocal Main = {}", out)
        end)

        it(
            "omits the header when disabled",
            function()
                assert.equal(
                    SCAFFOLD .. "\n\nMain.x = 5",
                    Codegen.new(build("private static x = 5"))
                        :generate({ header = false, entry = false })
                )
            end
        )
    end)

    describe("arithmetic / concat operators", function()
        -- function-local operands so they emit bare, isolating the operator
        -- (members would be qualified as Main.a / Main.b).
        local function emit_op(decls, expr)
            return compile("static f() {\n" .. decls .. "\nmut c = " .. expr .. "\n}")
        end
        local nums = "mut a = 1\nmut b = 2"
        local strs = 'mut a = "x"\nmut b = "y"'

        it(
            "emits '/' straight through",
            function() assert.matches("c = a / b", emit_op(nums, "a / b")) end
        )

        it(
            "emits '^' straight through",
            function() assert.matches("c = a %^ b", emit_op(nums, "a ^ b")) end
        )

        it(
            "emits '++' as Lua '..'",
            function() assert.matches("c = a %.%. b", emit_op(strs, "a ++ b")) end
        )

        it(
            "synthesises '%' for Lua 5.0 which has no '%' operator",
            function() assert.matches("%(a %- math%.floor%(a / b%) %* b%)", emit_op(nums, "a % b")) end
        )
    end)

    describe("constructor and construction", function()
        it(
            "lowers a constructor to C.new building a plain self table",
            function()
                assert.equal(
                    "function Main.new(x, y)\n    local self = {}\n    self.x = x\n    self.y = y\n    return self\nend",
                    members("private x\nprivate y\nconstructor(x, y) { .x = x\n.y = y }")
                )
            end
        )

        it(
            "lowers construction C(args) to C.new(args)",
            function()
                assert.matches(
                    "p = Main%.new%(3, 4%)",
                    members("static f() { mut p = Main(3, 4) }")
                )
            end
        )

        it(
            "does not treat a normal call as construction",
            function()
                assert.matches(
                    "Main%.helper%(%)",
                    members("static helper() { return 0 }\nstatic f() { helper() }")
                )
            end
        )
    end)

    describe("methods (instance vs static)", function()
        it(
            "lowers a static method to a plain class function (no self)",
            function()
                assert.equal(
                    "function Main.helper(n)\n    return n\nend",
                    members("static helper(n) { return n }")
                )
            end
        )

        it(
            "lowers an instance method with an implicit self parameter",
            function()
                assert.equal(
                    "function Main.greet(self)\n    return self.name\nend",
                    members("private name\ngreet() { return .name }")
                )
            end
        )

        it(
            "prepends self before the declared parameters of an instance method",
            function()
                assert.matches(
                    "function Main%.move%(self, dx, dy%)",
                    members("private x\nmove(dx, dy) { .x = dx }")
                )
            end
        )

        it(
            "dispatches obj.m(args) on an instance method to C.m(obj, args)",
            function()
                assert.matches(
                    "Main%.m%(p, 1%)",
                    members("m(a) { return a }\nstatic f(p) { p.m(1) }")
                )
            end
        )

        it(
            "dispatches .m() on the receiver to C.m(self)",
            function()
                assert.matches("Main%.go%(self%)", members("go() { return 0 }\nstep() { .go() }"))
            end
        )

        it(
            "dispatches a method call on a non-class receiver via colon (passes self)",
            function() assert.matches("p:go%(%)", members("static f(p) { p.go() }")) end
        )
    end)

    describe("field access", function()
        it(
            "emits field reads and assignments",
            function()
                assert.equal(
                    "function Main.f(p)\n    p.x = 3\n    return p.x\nend",
                    members("static f(p) { p.x = 3\nreturn p.x }")
                )
            end
        )

        it(
            "emits a compound field assignment desugared",
            function() assert.matches("p%.x = p%.x %+ 1", members("static f(p) { p.x += 1 }")) end
        )

        it(
            "emits a method call on a receiver via colon",
            function() assert.matches("p:go%(%)", members("static f(p) { p.go() }")) end
        )

        it(
            "emits a chained field read",
            function() assert.matches("return p%.x%.y", members("static f(p) { return p.x.y }")) end
        )
    end)

    describe("number literals", function()
        it(
            "emits a float literal as a plain Lua number",
            function() assert.equal("Main.pi = 3.14", members("private static pi = 3.14")) end
        )
    end)

    describe("footer (entry call)", function()
        it(
            "constructs and returns the instance via C.new(...) — the constructor is the entry",
            function()
                local out = compile_program("constructor() {}")
                assert.matches("return Main%.new%(%.%.%.%)$", out)
            end
        )

        it("errors when the entry class has no constructor", function()
            assert.has_error(function() compile_program("static other() { return 0 }") end)
        end)

        it("omits the footer when disabled", function()
            local out = Codegen.new(build("constructor() {}"))
                :generate({ header = true, entry = false })
            assert.is_nil(out:match("Main%.new%(%.%.%.%)"))
        end)
    end)

    describe("output is valid Lua", function()
        local cases = {
            "private x = 5",
            "private mut x",
            "public x = 5",
            "private static foo = 3 + 2\nprivate static bar = foo + 1",
            "private static a = 1\nprivate static b = (a + 1) * 2",
            'private s = "hello"',
            "static counter() { mut n = 0\nn = n + 1\nreturn n }",
            "static helper() { return 0 }",
            "private static mut a = 7\nprivate static mut b = 2\nprivate static q = a / b",
            "private static mut a = 7\nprivate static mut b = 2\nprivate static r = a % b",
            "private static mut a = 2\nprivate static mut b = 8\nprivate static p = a ^ b",
            'private static mut a = "x"\nprivate static mut b = "y"\nprivate static s = a ++ b',
        }

        -- Each fragment is a class body; a program needs a constructor (the
        -- entry point), so one is appended before compiling the full program.
        for _, src in ipairs(cases) do
            it("loads (full program): " .. src:gsub("\n", " / "), function()
                local out = compile_program(src .. "\nconstructor() {}")
                local chunk, err = load_chunk(out)
                assert.is_truthy(
                    chunk,
                    "generated code failed to load: " .. tostring(err) .. "\n" .. out
                )
            end)
        end
    end)
end)
