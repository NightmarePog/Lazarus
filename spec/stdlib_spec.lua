--- Stdlib integration tests.
---
--- Compiles + runs small programs against the real `std/*.laz` files: the extern
--- namespaces (Str/Num/Sys) and the typed Option/Result classes. The linker reads
--- the std sources from disk; the entry module is served in-memory from the
--- project root, so `import std.X` resolves to the real `std/X.laz` files.

local Linker = require("linker")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen = require("backend")

local load_chunk = loadstring or load
local ENTRY = "Spec.laz"

--- A `read_file` that serves `entry_src` for the virtual entry path and reads
--- everything else (the std files) from disk.
local function reader(entry_src)
    return function(path)
        if path == ENTRY then return entry_src end
        local fh = io.open(path, "r")
        if not fh then return nil, "no such file: " .. path end
        local s = fh:read("*a")
        fh:close()
        return s
    end
end

--- Build + run an in-memory entry program, returning the constructed instance.
local function run(entry_src)
    local modules, entry = Linker.link(ENTRY, reader(entry_src))
    for _, m in ipairs(modules) do
        Schematic.analyze(m.ast, m.source, m.class_name, m.imports)
        Optimizer.optimize(m.ast)
    end
    return assert(load_chunk(Codegen.bundle(modules, entry)))()
end

describe("stdlib", function()
    describe("extern namespaces", function()
        it("Str.upper goes through the extern boundary and unwraps", function()
            local inst = run(table.concat({
                'import std.Str',
                "private out",
                "constructor() {",
                '    .out = Str.upper("hello").unwrap()',
                "}",
            }, "\n"))
            assert.equal("HELLO", inst.out)
        end)

        it("Num.to_number returns None for a non-numeric string", function()
            local inst = run(table.concat({
                'import std.Num',
                "private bad",
                "constructor() {",
                '    .bad = Num.to_number("xyz").is_none()',
                "}",
            }, "\n"))
            assert.is_true(inst.bad)
        end)
    end)

    describe("typed Result", function()
        it("ok().take() returns the value", function()
            local inst = run(table.concat({
                'import std.ResultString',
                "private v",
                "constructor() {",
                '    mut r = ResultString.ok("yay")',
                "    .v = r.take()",
                "}",
            }, "\n"))
            assert.equal("yay", inst.v)
        end)

        it("err().take_or(d) returns the default", function()
            local inst = run(table.concat({
                'import std.ResultString',
                "private v",
                "constructor() {",
                '    mut r = ResultString.err("nope")',
                '    .v = r.take_or("fallback")',
                "}",
            }, "\n"))
            assert.equal("fallback", inst.v)
        end)

        it("err().take() panics", function()
            local src = table.concat({
                'import std.ResultString',
                "private v",
                "constructor() {",
                '    mut r = ResultString.err("boom")',
                "    .v = r.take()",
                "}",
            }, "\n")
            assert.has_error(function() run(src) end)
        end)
    end)

    describe("typed Option", function()
        it("some().take() and none().take_or(d)", function()
            local inst = run(table.concat({
                'import std.OptionInt',
                "private a",
                "private b",
                "constructor() {",
                "    mut some = OptionInt.some(42)",
                "    .a = some.take()",
                "    mut nope = OptionInt.none()",
                "    .b = nope.take_or(7)",
                "}",
            }, "\n"))
            assert.equal(42, inst.a)
            assert.equal(7, inst.b)
        end)
    end)
end)
