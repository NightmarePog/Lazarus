local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen   = require("backend")

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
local function compile_program(source)
    return Codegen.new(build(source)):generate()
end

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

describe("Codegen", function ()
    describe("emission", function ()
        it("emits a top-level binding as a class member", function ()
            assert.equal("Main.x = 5", members("private x = 5"))
        end)

        it("emits a valueless mutable binding as a nil member", function ()
            assert.equal("Main.x = nil", members("private mut x"))
        end)

        it("folds and emits an immutable member initialiser", function ()
            assert.equal("Main.foo = 5", members("private foo = 3 + 2"))
        end)

        it("emits a public binding as a member too (export is a Phase 6 concern)", function ()
            assert.equal("Main.x = 5", members("public x = 5"))
        end)

        it("emits a method with locals and a reassignment", function ()
            assert.equal("function Main.f()\n    local n = 0\n    n = 1\n    return n\nend",
                members("fn f() { mut n = 0\nn = 1\nreturn n }"))
        end)

        it("qualifies member references and parenthesises nested binary operands", function ()
            -- `a` is a mutable member, so it is not propagated/folded; references
            -- to it inside `b` are qualified as `Main.a`.
            assert.equal("Main.a = 1\nMain.b = (Main.a + 1) * 2",
                members("private mut a = 1\nprivate b = (a + 1) * 2"))
        end)

        it("emits string literals via %q", function ()
            assert.equal('Main.s = "hi"', members('private s = "hi"'))
        end)
    end)

    describe("control flow", function ()
        it("emits if / elseif / else", function ()
            local out = compile("fn f(a, b) { if a { x = 1 } else if b { x = 2 } else { x = 3 } }")
            assert.matches("if a then", out)
            assert.matches("elseif b then", out)
            assert.matches("\n    else\n", out)
            assert.matches("\n    end", out)
        end)

        it("emits a while loop", function ()
            local out = compile("fn f(n) { mut i = 0\nwhile i < n { i = i + 1 } }")
            assert.matches("while i < n do", out)
        end)

        it("emits loop as 'while true'", function ()
            local out = compile("fn f() { loop { break } }")
            assert.matches("while true do", out)
            assert.matches("break", out)
        end)

        it("lowers a C-style for to a do / while block", function ()
            local out = compile("fn f(n) { for i = 0; i < n; i += 1 { x = i } }")
            assert.matches("do", out)
            assert.matches("local i = 0", out)
            assert.matches("while i < n do", out)
            assert.matches("i = i %+ 1", out)
        end)

        it("emits comparison operators", function ()
            assert.matches("a == b", compile("fn f(a, b) { if a == b { x = 1 } }"))
        end)

        it("emits != as ~=", function ()
            assert.matches("a ~= b", compile("fn f(a, b) { if a != b { x = 1 } }"))
        end)

        it("emits and / or", function ()
            local out = compile("fn f(a, b) { if a and b { x = 1 } }")
            assert.matches("a and b", out)
        end)

        it("emits boolean literals", function ()
            local out = compile("fn f() { mut t = true\nt = false }")
            assert.matches("local t = true", out)
            assert.matches("t = false", out)
        end)

        it("emits unary not", function ()
            assert.matches("not a", compile("fn f(a) { if not a { x = 1 } }"))
        end)

        it("parenthesises a parenthesised binary operand of not", function ()
            assert.matches("not %(a == b%)", compile("fn f(a, b) { if not (a == b) { x = 1 } }"))
        end)
    end)

    describe("header", function ()
        it("emits a banner comment at the top by default", function ()
            local out = compile_program("private x = 5")
            assert.matches("^%-%-%-+\n%-%- Generated by the Lazarus compiler", out)
            assert.matches("Target runtime: Lua 5%.0", out)
        end)

        it("places the class body after the header", function ()
            local out = compile_program("private x = 5")
            assert.matches("\n\nlocal Main = {}", out)
        end)

        it("omits the header when disabled", function ()
            assert.equal(SCAFFOLD .. "\n\nMain.x = 5",
                Codegen.new(build("private x = 5")):generate({ header = false, entry = false }))
        end)
    end)

    describe("arithmetic / concat operators", function ()
        -- function-local operands so they emit bare, isolating the operator
        -- (members would be qualified as Main.a / Main.b).
        local function emit_op(decls, expr)
            return compile("fn f() {\n" .. decls .. "\nmut c = " .. expr .. "\n}")
        end
        local nums = "mut a = 1\nmut b = 2"
        local strs = 'mut a = "x"\nmut b = "y"'

        it("emits '/' straight through", function ()
            assert.matches("c = a / b", emit_op(nums, "a / b"))
        end)

        it("emits '^' straight through", function ()
            assert.matches("c = a %^ b", emit_op(nums, "a ^ b"))
        end)

        it("emits '++' as Lua '..'", function ()
            assert.matches("c = a %.%. b", emit_op(strs, "a ++ b"))
        end)

        it("synthesises '%' for Lua 5.0 which has no '%' operator", function ()
            assert.matches("%(a %- math%.floor%(a / b%) %* b%)", emit_op(nums, "a % b"))
        end)
    end)

    describe("field access", function ()
        it("emits field reads and assignments", function ()
            assert.equal("function Main.f(p)\n    p.x = 3\n    return p.x\nend",
                members("fn f(p) { p.x = 3\nreturn p.x }"))
        end)

        it("emits a compound field assignment desugared", function ()
            assert.matches("p%.x = p%.x %+ 1", members("fn f(p) { p.x += 1 }"))
        end)

        it("emits a method call", function ()
            assert.matches("p%.go%(%)", members("fn f(p) { p.go() }"))
        end)

        it("emits a chained field read", function ()
            assert.matches("return p%.x%.y", members("fn f(p) { return p.x.y }"))
        end)
    end)

    describe("type annotations are erased", function ()
        it("emits the same Lua with or without a binding annotation", function ()
            assert.equal(compile("private x = 5"), compile("private x: int = 5"))
        end)

        it("erases parameter and return annotations on a function", function ()
            local typed   = compile("fn add(a: int, b: int): int { return a + b }")
            local untyped = compile("fn add(a, b) { return a + b }")
            assert.equal(untyped, typed)
        end)

        it("emits a float literal as a plain Lua number", function ()
            assert.equal("Main.pi = 3.14", members("private pi: float = 3.14"))
        end)
    end)

    describe("footer (entry call)", function ()
        it("appends C.main() then returns the class when a main is present", function ()
            local out = compile_program("fn main() { return 0 }")
            assert.matches("Main%.main%(%)\nreturn Main$", out)
        end)

        it("does not append main() when there is no main", function ()
            local out = compile_program("fn other() { return 0 }")
            assert.is_nil(out:match("main%(%)"))
        end)

        it("omits the footer when disabled", function ()
            local out = Codegen.new(build("fn main() { return 0 }"))
                :generate({ header = true, entry = false })
            assert.is_nil(out:match("\nmain%(%)"))
        end)
    end)

    describe("output is valid Lua", function ()
        local cases = {
            "private x = 5",
            "private mut x",
            "public x = 5",
            "private foo = 3 + 2\nprivate bar = foo + 1",
            "private a = 1\nprivate b = (a + 1) * 2",
            'private s = "hello"',
            "fn counter() { mut n = 0\nn = n + 1\nreturn n }",
            "fn main() { return 0 }",
            "private mut a = 7\nprivate mut b = 2\nprivate q = a / b",
            "private mut a = 7\nprivate mut b = 2\nprivate r = a % b",
            "private mut a = 2\nprivate mut b = 8\nprivate p = a ^ b",
            'private mut a = "x"\nprivate mut b = "y"\nprivate s = a ++ b',
        }

        for _, src in ipairs(cases) do
            it("loads (full program): " .. src:gsub("\n", " / "), function ()
                local out = compile_program(src)
                local chunk, err = load_chunk(out)
                assert.is_truthy(chunk, "generated code failed to load: " .. tostring(err) .. "\n" .. out)
            end)
        end
    end)
end)
