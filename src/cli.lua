--- Lazarus compiler command-line entry point.
---
--- Usage:
---   lazarus build <file.laz> [-o <out.lua>]   compile to Lua (default: <file>.lua)
---   lazarus check <file.laz>                  parse + analyse, report errors only
---   lazarus ast   <file.laz>                  dump the optimised AST
---   lazarus help                              show this message
---   lazarus version                           print the compiler version
---
--- `-o -` writes generated Lua to stdout instead of a file.

-- Resolve module paths relative to this script so the CLI works from any cwd.
local script = (arg and arg[0]) or ""
local base = script:match("^(.*)[/\\]") or "."
package.path = table.concat({
    base .. "/?.lua",
    base .. "/?/init.lua",
    package.path,
}, ";")

local Schematic = require("frontend.schematic")
local Optimizer = require("frontend.optimizer")
local Codegen = require("backend")
local Linker = require("linker")
local const = require("const")

local PROG = "lazarus"

--- Print a message to stderr.
---@param ... string
local function eprint(...)
    -- selene: allow(incorrect_standard_library_use)
    io.stderr:write(table.concat({ ... }, "\t") .. "\n")
end

--- Print the usage text.
local function usage()
    print(
        ([[
%s — the Lazarus compiler (v%s)

Usage:
  %s build <file.laz> [-o <out.lua>]   compile to Lua (default: <file>.lua)
  %s check <file.laz>                  parse + analyse, report errors only
  %s ast   <file.laz>                  dump the optimised AST
  %s help                              show this message
  %s version                           print the compiler version

Options:
  -o, --out <path>    output file for `build`; use `-` for stdout

Set LAZARUS_DEBUG=1 to append an internal stack trace to errors.]]):format(
            PROG,
            const.compiler_version,
            PROG,
            PROG,
            PROG,
            PROG,
            PROG
        )
    )
end

--- Read a whole file. Returns `nil, err` on failure rather than exiting, so the
--- linker can turn a missing import into a positioned compile error.
---@param path string
---@return string | nil source
---@return string | nil err
local function read_source(path)
    local fh, err = io.open(path, "r")
    if not fh then return nil, err or "file not found" end
    local contents = fh:read("*a")
    fh:close()
    return contents
end

--- Write `contents` to `path`, or exit on failure.
---@param path     string
---@param contents string
local function write_file(path, contents)
    local fh, err = io.open(path, "w")
    if not fh then
        eprint(PROG .. ": cannot write '" .. path .. "': " .. (err or "unknown error"))
        os.exit(1)
        return
    end
    fh:write(contents)
    fh:close()
end

--- Replace a trailing `.laz` (or any extension) with `.lua` for the default
--- build output path. Names without an extension just get `.lua` appended.
---@param path string
---@return string
local function default_output(path)
    local stem = path:gsub("%.[^./\\]*$", "")
    return stem .. ".lua"
end

--- Forward declaration: `run_stage` is defined below but captured by the
--- closures in `link`/`analyze_modules` above it.
---@type fun(fn: fun(): any...): any...
local run_stage

--- Resolve the program reachable from `entry`: lex + parse every file, follow
--- imports, and return the modules **dependencies-first** plus the entry class.
--- Any compile error is an `Error` object; `run_stage` renders it.
---@param entry string
---@return { path: string, class_name: string, source: string, ast: AST, imports: string[] }[] modules
---@return string entry_class
local function link(entry)
    local modules, entry_class = run_stage(function() return Linker.link(entry, read_source) end)
    return modules, entry_class
end

--- Run schematic analysis + the optimizer over each linked module in place.
--- Imported class names are passed so cross-class references resolve.
---@param modules { class_name: string, source: string, ast: AST, imports: string[] }[]
local function analyze_modules(modules)
    run_stage(function()
        for _, m in ipairs(modules) do
            Schematic.analyze(m.ast, m.source, m.class_name, m.imports)
            Optimizer.optimize(m.ast)
        end
    end)
end

--- Render any value as an indented tree (used by the `ast` command).
---@param val    any
---@param indent integer?
---@return string
local function dump(val, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)

    if type(val) ~= "table" then return tostring(val) or "" end

    local lines = { "{" }
    for k, v in pairs(val) do
        local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
        lines[#lines + 1] = pad .. "  " .. key .. " = " .. dump(v, indent + 1)
    end
    lines[#lines + 1] = pad .. "}"
    return table.concat(lines, "\n")
end

--- Run `fn` (a pipeline step that may throw an `Error`) and turn any failure
--- into a clean diagnostic + non-zero exit. `Error` objects render their own
--- coloured box via `tostring`; anything else is an internal compiler bug.
---@generic T
---@param fn fun(): T...
---@return T...
function run_stage(fn)
    -- Capture *all* return values: some stages (the linker) return more than one.
    ---@type any[]
    local results = { pcall(fn) }
    -- selene: allow(incorrect_standard_library_use)
    if results[1] then return (table.unpack or unpack)(results, 2, #results) end
    -- `results[2]` is the thrown value: an Error object (table with __tostring) or
    -- a raw string for an unexpected internal failure.
    local thrown = results[2]
    eprint(tostring(thrown) or "")
    os.exit(1)
end

local commands = {}

--- `build` — full pipeline, write Lua to a file (or stdout with `-o -`).
---@param args string[]
function commands.build(args)
    local input, output
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-o" or a == "--out" then
            output = args[i + 1]
            if not output then
                eprint(PROG .. ": " .. a .. " requires a path")
                os.exit(1)
            end
            i = i + 2
        elseif not input then
            input = a
            i = i + 1
        else
            eprint(PROG .. ": unexpected argument '" .. a .. "'")
            os.exit(1)
        end
    end

    if not input then
        eprint(PROG .. ": build requires an input file")
        os.exit(1)
        return
    end

    local modules, entry_class = link(input)
    analyze_modules(modules)
    local lua = run_stage(function() return Codegen.bundle(modules, entry_class) end)

    if output == "-" then
        print(lua)
    else
        output = output or default_output(input)
        write_file(output, lua)
        eprint(PROG .. ": wrote " .. output)
    end
end

--- `check` — run the front end only; succeed silently, fail with a diagnostic.
---@param args string[]
function commands.check(args)
    local input = args[1]
    if not input then
        eprint(PROG .. ": check requires an input file")
        os.exit(1)
        return
    end

    local modules = link(input)
    analyze_modules(modules)
    eprint(PROG .. ": " .. input .. " — no errors")
end

--- `ast` — dump the optimised AST.
---@param args string[]
function commands.ast(args)
    local input = args[1]
    if not input then
        eprint(PROG .. ": ast requires an input file")
        os.exit(1)
        return
    end

    local modules, entry_class = link(input)
    analyze_modules(modules)
    -- Dump the entry class's optimised AST (it is the last, dependencies-first).
    for _, m in ipairs(modules) do
        if m.class_name == entry_class then print(dump(m.ast)) end
    end
end

function commands.help() usage() end

function commands.version() print(PROG .. " " .. const.compiler_version) end

local function main()
    local command = arg[1]

    if not command or command == "-h" or command == "--help" then
        usage()
        os.exit(command and 0 or 1)
    end
    if command == "--version" or command == "-v" then command = "version" end

    local handler = commands[command]
    if not handler then
        eprint(PROG .. ": unknown command '" .. command .. "'")
        eprint("Run '" .. PROG .. " help' for usage.")
        os.exit(1)
        return
    end

    -- Pass the remaining arguments (everything after the command word).
    local rest = {}
    for i = 2, #arg do
        rest[#rest + 1] = arg[i]
    end
    handler(rest)
end

main()
