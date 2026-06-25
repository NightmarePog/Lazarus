--- Linker / module loader.
---
--- Lazarus has no runtime module system: a program is **bundled at compile time
--- into one Lua chunk**. The linker is the front of that process. Starting from
--- the entry file it lexes + parses each `.laz`, extracts its `import`
--- declarations, resolves them to files, and recurses — producing the full set
--- of classes the program needs, ordered **dependencies-first** so that a
--- class's emitted code (and its top-level/static initialisers) appears before
--- any class that uses it.
---
--- Imports are stripped from each AST here, so every later stage (schematic,
--- optimizer, codegen) sees an ordinary single-class `Program` and never needs
--- to know imports exist. The only thing the linker hands forward about them is
--- the list of imported class *names* per module, so the checker can treat them
--- as visible and codegen can lower `Name(...)` construction.

local Lexer = require("frontend.lexer")
local Parser = require("frontend.parser")
local Error = require("error")

local Linker = {}

--- Directory part of a path (everything up to the last separator), or nil when
--- the path has no directory component.
---@param path string
---@return string | nil
local function dirname(path) return path:match("^(.*)[/\\]") end

--- The file stem: basename without directory or extension. `src/Vec2.laz` -> `Vec2`.
---@param path string
---@return string
local function stem(path)
    local base = path:match("([^/\\]+)$") or path
    return (base:gsub("%.[^.]*$", ""))
end

--- Join a directory and a relative path. A nil/empty directory yields `rel`
--- unchanged (the file sits in the current directory).
---@param dir string | nil
---@param rel string
---@return string
local function join(dir, rel)
    if not dir or dir == "" then return rel end
    return dir .. "/" .. rel
end

--- Resolve one import to a source path, always from the project root.
---   `import a.b.Name` -> `<source_root>/a/b/Name.laz`
--- The path is project-root-relative regardless of which file the import sits in,
--- so there is no `../` form and no importer-relative resolution.
---@param node        ImportDecl
---@param source_root string | nil  Directory of the entry file (the project root)
---@return string
local function resolve(node, source_root)
    return join(source_root, table.concat(node.segments, "/") .. ".laz")
end

--- Lex + parse one file and split its top-level `import`s out of the body.
---@param source string
---@return AST                ast      The Program with imports removed
---@return ImportDecl[]       imports  The extracted import declarations
local function parse_module(source)
    local ast = Parser.new(Lexer.new(source):scan(), source):parse()

    local imports = {}
    local body = {}
    for _, node in ipairs(ast.body) do
        if node.type == "ImportDecl" then
            imports[#imports + 1] = node
        else
            body[#body + 1] = node
        end
    end
    ast.body = body
    return ast, imports
end

--- Resolve the whole program reachable from `entry_path`.
---
--- `read_file(path)` must return the file's contents, or `nil, err` when the
--- file cannot be read; the linker turns a miss into a `SEMANTIC_ERROR` pointing
--- at the offending `import`.
---
---@param entry_path string
---@param read_file  fun(path: string): string | nil, string | nil
---@return { path: string, class_name: string, source: string, ast: AST, imports: string[] }[] modules  Dependencies-first
---@return string entry_class  Class name of the entry file
function Linker.link(entry_path, read_file)
    local source_root = dirname(entry_path)

    ---@type table<string, table?>  resolved path -> module (also marks "done")
    local loaded = {}
    ---@type table<string, boolean>  resolved path -> currently on the DFS stack
    local visiting = {}
    ---@type table[]
    local ordered = {}

    --- Load `path` and everything it imports, appending dependencies before self.
    --- `origin` is the import node that referenced this file (nil for the entry),
    --- used to position a "cannot resolve" error.
    ---@param path   string
    ---@param origin ImportDecl | nil
    local function load(path, origin)
        if loaded[path] then return end
        -- A cycle: the file is already being processed further up the stack.
        -- Type-reference cycles are allowed (each class is still emitted once);
        -- we simply do not re-enter it here.
        if visiting[path] then return end
        visiting[path] = true

        local source, err = read_file(path)
        if not source then
            -- The import's line/col belong to the *importing* file, whose source
            -- is not in scope here, so render the location without a snippet.
            Error.throw(
                Error.Type.SEMANTIC_ERROR,
                "Cannot resolve import '" .. path .. "': " .. (err or "file not found"),
                origin and origin.line,
                origin and origin.col
            )
            return
        end

        local class_name = stem(path)
        local ast, imports = parse_module(source)

        ---@type string[]
        local import_names = {}
        for _, node in ipairs(imports) do
            -- The class name is the final path segment by construction, so it
            -- always matches the file stem; resolution is purely root-relative.
            local dep_path = resolve(node, source_root)
            load(dep_path, node)
            import_names[#import_names + 1] = node.name
        end

        local module = {
            path = path,
            class_name = class_name,
            source = source,
            ast = ast,
            imports = import_names,
        }
        ordered[#ordered + 1] = module
        loaded[path] = module
        visiting[path] = nil
    end

    load(entry_path, nil)
    return ordered, stem(entry_path)
end

return Linker
