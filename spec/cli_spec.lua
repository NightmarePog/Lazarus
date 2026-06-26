--- CLI entry-point tests.
---
--- These drive the *actual* compiler entry point (`src/cli.lua`) as a
--- subprocess — the same way a user runs it — and assert on its stdout and exit
--- code. Generated Lua is then loaded and executed to confirm it is correct,
--- not merely well-formed. The pure-pipeline behaviour is covered separately by
--- `integration_spec`; this file is specifically about the command-line wiring.

local load_chunk = loadstring or load

-- Interpreter used to run the CLI. The project (makefile, README) assumes `lua`
-- is on PATH; override with LAZARUS_LUA when testing under a different binary.
local LUA = os.getenv("LAZARUS_LUA") or "lua"

--- Run the CLI with `args` (a raw argument string) and capture its stdout and
--- exit code. stderr is discarded — diagnostics go there by design, and these
--- tests assert on the exit code instead of matching error text. The exit code
--- is smuggled out on a trailing `LAZ_EXIT:<n>` line appended by the shell.
---@param args string
---@return string stdout, number code
local function run(args)
    local cmd = LUA .. " src/cli.lua " .. args .. ' 2>/dev/null; echo "LAZ_EXIT:$?"'
    -- io.popen can return nil on failure, so this assert is intentional; the
    -- stdlib stub types it as non-nil, hence the false-positive suppression.
    ---@diagnostic disable-next-line: unnecessary-assert
    local proc = assert(io.popen(cmd, "r"))
    local out = proc:read("*a")
    proc:close()

    local code = tonumber(out:match("LAZ_EXIT:(%d+)%s*$")) or -1
    out = out:gsub("LAZ_EXIT:%d+%s*$", "")
    return out, code
end

--- Write `src` to a temp file named `Prog.laz` (a fixed PascalCase basename, so
--- the generated class name is the predictable `Prog`) and return its path.
---@param src string
---@return string path
local function tmp_laz(src)
    local stem = os.tmpname()
    os.remove(stem) -- os.tmpname may create an empty file; we want our own name
    local dir = stem:match("^(.*)[/\\][^/\\]*$") or "."
    local path = dir .. "/Prog.laz"
    local fh = assert(io.open(path, "w"))
    fh:write(src)
    fh:close()
    return path
end

--- Read a whole file (or nil if it does not exist).
---@param path string
---@return string?
local function read(path)
    local fh = io.open(path, "r")
    if not fh then return nil end
    local data = fh:read("*a")
    fh:close()
    return data
end

--- Plain (non-pattern) substring search.
local function has(haystack, needle) return haystack:find(needle, 1, true) ~= nil end

-- square(7) = 49; stored on the instance field `answer` by the constructor
-- (the program entry point).
local PROGRAM = [[
private static seed = 7

private answer

static square(n) {
    return n * n
}

constructor() {
    .answer = square(seed)
}
]]

describe("CLI", function()
    describe("build", function()
        it("compiles a program to Lua on stdout (-o -)", function()
            local laz = tmp_laz(PROGRAM)
            local out, code = run("build " .. laz .. " -o -")
            os.remove(laz)

            assert.equal(0, code)
            assert.is_true(has(out, "function Prog.square(n)"))
            assert.is_true(has(out, "self.answer = Prog.square(7)"))
            assert.is_true(has(out, "return Prog.new(...)"))
        end)

        it("generates Lua that loads and runs to the right result", function()
            local laz = tmp_laz(PROGRAM)
            local out, code = run("build " .. laz .. " -o -")
            os.remove(laz)

            assert.equal(0, code)
            -- The chunk runs the constructor and returns the instance; read its field.
            local inst = assert(load_chunk(out), "generated Lua failed to load")()
            assert.equal(49, inst.answer)
        end)

        it("writes <file>.lua next to the source by default", function()
            local laz = tmp_laz(PROGRAM)
            local expected = laz:gsub("%.laz$", ".lua")
            os.remove(expected)

            local _, code = run("build " .. laz)
            assert.equal(0, code)

            local written = read(expected)
            assert.is_truthy(written, "expected output file was not created")
            assert.is_true(has(written, "function Prog.square(n)"))

            os.remove(laz)
            os.remove(expected)
        end)

        it("exits non-zero with no input file", function()
            local _, code = run("build")
            assert.is_true(code ~= 0)
        end)

        it("links and runs a multi-file program (imports + cross-class dispatch)", function()
            -- Two classes in one temp dir: Main imports Box, constructs it, and
            -- calls an *instance* method across the file boundary.
            local stem = os.tmpname()
            os.remove(stem)
            local dir = stem:match("^(.*)[/\\][^/\\]*$") or "."

            local function write(name, src)
                local path = dir .. "/" .. name
                local fh = assert(io.open(path, "w"))
                fh:write(src)
                fh:close()
                return path
            end

            local box = write(
                "Box.laz",
                "private value\nread() { return .value }\nconstructor(v) { .value = v }\n"
            )
            local main = write(
                "Main.laz",
                "import Box\nprivate result\nconstructor() {\nmut b = Box(7)\n.result = b.read()\n}\n"
            )

            local out, code = run("build " .. main .. " -o -")
            os.remove(box)
            os.remove(main)

            assert.equal(0, code)
            -- Box is emitted before Main (dependencies first) and the call uses colon.
            assert.is_true(has(out, "local Box = {}"))
            assert.is_true(has(out, "b:read()"))
            local inst = assert(load_chunk(out), "generated Lua failed to load")()
            assert.equal(7, inst.result)
        end)
    end)

    describe("check", function()
        it("succeeds (exit 0) on a valid program", function()
            local laz = tmp_laz(PROGRAM)
            local _, code = run("check " .. laz)
            os.remove(laz)
            assert.equal(0, code)
        end)

        it("fails (non-zero) on an undeclared identifier", function()
            local laz = tmp_laz("private x = undefined_var\n")
            local _, code = run("check " .. laz)
            os.remove(laz)
            assert.is_true(code ~= 0)
        end)

        it("fails (non-zero) on a syntax error", function()
            local laz = tmp_laz("constructor( {\n")
            local _, code = run("check " .. laz)
            os.remove(laz)
            assert.is_true(code ~= 0)
        end)
    end)

    describe("ast", function()
        it("dumps the AST and exits 0", function()
            local laz = tmp_laz(PROGRAM)
            local out, code = run("ast " .. laz)
            os.remove(laz)

            assert.equal(0, code)
            assert.is_true(has(out, "FunctionDecl"))
            assert.is_true(has(out, "VariableDecl"))
        end)
    end)

    describe("meta commands", function()
        it("prints a version and exits 0", function()
            local out, code = run("version")
            assert.equal(0, code)
            assert.is_true(has(out, "lazarus"))
        end)

        it("rejects an unknown command (non-zero)", function()
            local _, code = run("frobnicate")
            assert.is_true(code ~= 0)
        end)
    end)
end)
