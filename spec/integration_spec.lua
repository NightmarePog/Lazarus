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

-- What each piece exercises (and the arithmetic it folds to):
--   base  = 2 * 3 + 1        -> 7   immutable; folds and propagates
--   scale = (base + 3) * 2   -> 20  folds using the propagated `base`
--   step(v)  = v * 2 + base  -> mut local reassigned twice, sees outer `base`
--   bump(x)  = x + base          nested function, also sees outer `base`
--   answer / label               public globals written by `main`
local PROGRAM = [[
private base  = 2 * 3 + 1
private scale = (base + 3) * 2

public mut hits = 0

static square(n) {
    return n * n
}

static step(v) {
    mut r = v
    r = r * 2
    r = r + base
    return r
}

static compute(seed) {
    bump(x) {
        return x + base
    }

    mut total = seed
    total = total + square(seed)
    total = step(total)
    total = bump(total)
    total = total + scale
    return total
}

static brand() {
    return "lazarus"
}

constructor() {
    self.answer = compute(4)
    self.label  = brand()
}
]]

describe("Integration", function ()
    describe("code generation", function ()
        local body = compile(PROGRAM, { header = false, entry = false })

        it("folds an immutable initialiser", function ()
            assert.is_true(has(body, "Main.base = 7"))
        end)

        it("propagates one immutable into another's initialiser", function ()
            assert.is_true(has(body, "Main.scale = 20"))
        end)

        it("propagates an outer immutable into a function body", function ()
            assert.is_true(has(body, "r = r + 7"))
        end)

        it("propagates an outer immutable into a nested function body", function ()
            assert.is_true(has(body, "local function bump(x)"))
            assert.is_true(has(body, "return x + 7"))
        end)

        it("lowers a public binding to a class member (no `local`)", function ()
            assert.is_true(has(body, "Main.hits = 0"))
            assert.is_false(has(body, "local hits"))
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
            -- The chunk runs the constructor and returns the instance, whose
            -- fields hold the results.
            local inst = assert(load_chunk(compile(PROGRAM)))()
            assert.equal(74, inst.answer)
            assert.equal("lazarus", inst.label)
        end)
    end)

    describe("recursion (self-reference)", function ()
        it("compiles a function that refers to itself", function ()
            local out = compile("static recur() { return recur }\nconstructor() {}")
            assert.is_truthy(load_chunk(out), "self-referential function failed to load")
        end)
    end)

    describe("control flow", function ()
        -- Exercises every control-flow form at once: if/else if/else, a C-style
        -- for with compound assignment, while, an explicit loop with break, plus
        -- comparison operators, booleans and `not`.
        local CF_PROGRAM = [[
static classify(n) {
    if n < 0 {
        return "neg"
    } else if n == 0 {
        return "zero"
    } else {
        return "pos"
    }
}

static sum_to(n) {
    mut acc = 0
    for i = 1; i <= n; i += 1 {
        acc += i
    }
    return acc
}

static count_down(n) {
    mut cnt = 0
    mut k   = n
    while k > 0 {
        k   -= 1
        cnt += 1
    }
    return cnt
}

static first_four() {
    mut i = 1
    loop {
        if i == 4 {
            break
        }
        i += 1
    }
    return i
}

constructor() {
    self.total     = sum_to(5)
    self.steps     = count_down(7)
    self.firsteven = first_four()
    self.flag      = not (self.total == 0)
    self.label     = classify(0 - 3)
}
]]

        it("generates Lua that loads", function ()
            local chunk, err = load_chunk(compile(CF_PROGRAM))
            assert.is_truthy(chunk, "failed to load: " .. tostring(err))
        end)

        it("lowers the C-style for to a do/while block", function ()
            local body = compile(CF_PROGRAM, { header = false, entry = false })
            assert.is_true(has(body, "while i <= n do"))
            assert.is_true(has(body, "i = i + 1"))
        end)

        it("produces the correct runtime results", function ()
            local inst = assert(load_chunk(compile(CF_PROGRAM)))()

            assert.equal(15, inst.total)      -- 1+2+3+4+5
            assert.equal(7,  inst.steps)      -- counted down from 7
            assert.equal(4,  inst.firsteven)  -- loop breaks at i == 4
            assert.equal(true, inst.flag)     -- not (15 == 0)
            assert.equal("neg", inst.label)   -- classify(-3)
        end)
    end)

    describe("constructor and instances", function ()
        -- The constructor is the entry point: the chunk is `return Main.new(...)`,
        -- so launch arguments flow into the constructor and the instance is
        -- returned. `sum_coords` is a static helper; `bump` is an instance method
        -- dispatched as `Main.bump(self)`.
        local PROG = [[
static sum_coords(p) {
    return p.x + p.y
}

bump() {
    self.x = self.x + 10
}

constructor(x, y) {
    self.x = x
    self.y = y
    self.bump()
    self.sum = sum_coords(self)
}
]]

        it("lowers the constructor to a plain-table C.new and dispatches the instance method", function ()
            local body = compile(PROG, { header = false, entry = false })
            assert.is_true(has(body, "function Main.new(x, y)"))
            assert.is_true(has(body, "local self = {}"))
            assert.is_true(has(body, "function Main.bump(self)"))
            assert.is_true(has(body, "Main.bump(self)"))       -- self.bump() dispatch
            assert.is_true(has(body, "Main.sum_coords(self)")) -- static helper call
        end)

        it("constructs an instance and reads/writes its fields at runtime", function ()
            -- Launch args 3, 4 flow into the constructor (return Main.new(...)).
            local inst = assert(load_chunk(compile(PROG)))(3, 4)
            assert.equal(13, inst.x)   -- 3, bumped by 10
            assert.equal(4,  inst.y)
            assert.equal(17, inst.sum) -- (3 + 10) + 4
        end)
    end)

    describe("arithmetic, concat and comments", function ()
        -- Exercises /, %, ^, ++ and compound /=, plus both comment forms,
        -- through the whole pipeline and at runtime.
        local PROG = [[
// division, modulo, power, concat and compound /=
constructor() {
    mut x = 20
    x /= 2          // x is now 10
    self.q = x
    self.r = x % 3       /* 10 mod 3 = 1 */
    self.p = 2 ^ 4       // folds to 16
    self.greeting = "hi, " ++ "laz"
}
]]

        it("generates Lua that loads", function ()
            local chunk, err = load_chunk(compile(PROG))
            assert.is_truthy(chunk, "failed to load: " .. tostring(err))
        end)

        it("synthesises modulo with math.floor in the emitted Lua", function ()
            local body = compile(PROG, { header = false, entry = false })
            assert.is_true(has(body, "math.floor"))
        end)

        it("produces the correct runtime results", function ()
            local inst = assert(load_chunk(compile(PROG)))()

            assert.equal(10, inst.q)            -- 20 /= 2
            assert.equal(1,  inst.r)            -- 10 % 3
            assert.equal(16, inst.p)            -- 2 ^ 4
            assert.equal("hi, laz", inst.greeting)
        end)
    end)
end)
