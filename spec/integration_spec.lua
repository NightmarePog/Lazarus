--- End-to-end integration test.
---
--- Compiles a non-trivial program through the whole pipeline
--- (Lexer → Parser → Schematic → Optimizer → Codegen) and then *executes* the
--- generated Lua, asserting both the emitted code and its runtime behaviour.
--- This exercises every language feature at once: immutable folding and
--- propagation, `public` globals, `mut` locals with reassignment, function
--- parameters, nested functions, string literals, and the `main()` entry call.

local Lexer     = require("frontend.lexer")
local Parser    = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen   = require("backend")

local load_chunk = loadstring or load

--- Full pipeline. `opts` is forwarded to codegen (header/entry toggles).
local function compile(source, opts)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()
    Schematic.analyze(ast, source)
    Optimizer.optimize(ast)
    return Codegen.new(ast):generate(opts)
end

--- Plain (non-pattern) substring search.
local function has(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

-- Lazarus has no comment syntax yet, so the program below is comment-free.
-- What each piece exercises (and the arithmetic it folds to):
--   base  = 2 * 3 + 1        -> 7   immutable; folds and propagates
--   scale = (base + 3) * 2   -> 20  folds using the propagated `base`
--   step(v)  = v * 2 + base  -> mut local reassigned twice, sees outer `base`
--   bump(x)  = x + base          nested function, also sees outer `base`
--   answer / label               public globals written by `main`
local PROGRAM = [[
private base  = 2 * 3 + 1
private scale = (base + 3) * 2

public mut answer = 0
public mut label  = "none"

fn square(n) {
    return n * n
}

fn step(v) {
    mut r = v
    r = r * 2
    r = r + base
    return r
}

fn compute(seed) {
    fn bump(x) {
        return x + base
    }

    mut total = seed
    total = total + square(seed)
    total = step(total)
    total = bump(total)
    total = total + scale
    return total
}

fn brand() {
    return "lazarus"
}

fn main() {
    answer = compute(4)
    label  = brand()
    return answer
}
]]

describe("Integration", function ()
    describe("code generation", function ()
        local body = compile(PROGRAM, { header = false, entry = false })

        it("folds an immutable initialiser", function ()
            assert.is_true(has(body, "local base = 7"))
        end)

        it("propagates one immutable into another's initialiser", function ()
            assert.is_true(has(body, "local scale = 20"))
        end)

        it("propagates an outer immutable into a function body", function ()
            assert.is_true(has(body, "r = r + 7"))
        end)

        it("propagates an outer immutable into a nested function body", function ()
            assert.is_true(has(body, "local function bump(x)"))
            assert.is_true(has(body, "return x + 7"))
        end)

        it("lowers a public binding to a global (no `local`)", function ()
            assert.is_true(has(body, "answer = 0"))
            assert.is_false(has(body, "local answer"))
        end)

        it("lowers a reassignment without `local`", function ()
            -- declaration keeps `local`, later writes drop it
            assert.is_true(has(body, "local r = v"))
            assert.is_true(has(body, "r = r * 2"))
            assert.is_false(has(body, "local r = r"))
        end)
    end)

    describe("execution", function ()
        it("generates Lua that loads", function ()
            local chunk, err = load_chunk(compile(PROGRAM))
            assert.is_truthy(chunk, "failed to load: " .. tostring(err))
        end)

        it("produces the correct runtime results", function ()
            -- compute(4):
            --   total = 4
            --   total = 4 + square(4)   = 4 + 16 = 20
            --   total = step(20)        = 20*2 + 7 = 47
            --   total = bump(47)        = 47 + 7   = 54
            --   total = 54 + scale(20)            = 74
            _G.answer, _G.label = nil, nil
            local chunk = assert(load_chunk(compile(PROGRAM)))
            chunk() -- the appended main() call runs the program

            assert.equal(74, _G.answer)
            assert.equal("lazarus", _G.label)

            _G.answer, _G.label = nil, nil
        end)
    end)

    describe("recursion (self-reference)", function ()
        it("compiles a function that refers to itself", function ()
            local out = compile("fn loop() { return loop }\nfn main() { return loop }")
            assert.is_truthy(load_chunk(out), "self-referential function failed to load")
        end)
    end)
end)
