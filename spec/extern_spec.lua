--- `extern` tests.
---
--- An extern namespace file (its body is only `extern` declarations) binds
--- members to raw Lua names. It is imported like any class and called qualified
--- (`Sys.sub(...)`); the call lowers to the raw Lua target applied to the
--- forwarded args, with the result wrapped at the Option boundary. The namespace
--- file itself emits no class.

local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Linker = require("linker")
local Codegen = require("backend")

local function parse(source) return Parser.new(Lexer.new(source):scan(), source):parse() end

--- Build a `read_file` over an in-memory `{ [path] = source }` table.
local function reader(files)
    return function(path)
        local src = files[path]
        if src then return src end
        return nil, "no such virtual file"
    end
end

--- Link + analyze + bundle an in-memory program, returning the emitted Lua.
local function bundle(files, entry_path)
    local modules, entry = Linker.link(entry_path, reader(files))
    for _, m in ipairs(modules) do
        Schematic.analyze(m.ast, m.source, m.class_name, m.imports)
        Optimizer.optimize(m.ast)
    end
    return Codegen.bundle(modules, entry)
end

-- A namespace file plus a user of it. `string.upper` is total, so the wrapped
-- result is immediately unwrapped at the call site.
local PROGRAM = {
    ["Sys.laz"] = 'extern upper(s) = "string.upper"\n',
    ["Main.laz"] = table.concat({
        "import Sys",
        "",
        "private result",
        "",
        "constructor() {",
        '    .result = Sys.upper("hi").unwrap()',
        "}",
    }, "\n"),
}

describe("extern", function()
    describe("parsing", function()
        it("parses an extern declaration into an ExternDecl node", function()
            local node = parse('extern sub(s, i, j) = "string.sub"').body[1]
            assert.equal("ExternDecl", node.type)
            assert.equal("sub", node.name)
            assert.same({ "s", "i", "j" }, node.params)
            assert.equal("string.sub", node.target)
        end)

        it("parses a zero-parameter extern", function()
            local node = parse('extern now() = "os.time"').body[1]
            assert.equal("ExternDecl", node.type)
            assert.same({}, node.params)
            assert.equal("os.time", node.target)
        end)
    end)

    describe("codegen", function()
        it("lowers a qualified extern call to the raw Lua target, Option-wrapped", function()
            local lua = bundle(PROGRAM, "Main.laz")
            assert.truthy(lua:find('__lz_wrap(string.upper("hi"))', 1, true))
            -- `.unwrap()` on the result composes over the wrapped call.
            assert.truthy(lua:find("__lz_unwrap(__lz_wrap(string.upper", 1, true))
        end)

        it("emits no class table for an extern namespace file", function()
            local lua = bundle(PROGRAM, "Main.laz")
            assert.is_nil(lua:find("local Sys = {}", 1, true))
        end)

        it("emits the runtime prelude exactly once for the whole bundle", function()
            local lua = bundle(PROGRAM, "Main.laz")
            -- `__lz_each` appears only in the prelude, so its count is the number
            -- of prelude copies emitted.
            local _, preludes = lua:gsub("__lz_each", "")
            assert.equal(1, preludes)
        end)

        it("runs: the wrapped extern call produces the expected value", function()
            local lua = bundle(PROGRAM, "Main.laz")
            local chunk = assert((loadstring or load)(lua))
            assert.equal("HI", chunk().result)
        end)
    end)
end)
