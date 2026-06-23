--- AST node for an `import` declaration.
---
--- `import seg.seg.Class` is a dot-separated path resolved from the project root
--- (the entry file's directory). `segments` holds the path parts in order; the
--- last is the class name (`name`) and the file stem, the rest are folders.
--- `import std.Str` -> segments `{"std","Str"}`, name `Str`, file
--- `<root>/std/Str.laz`, used qualified as `Str(...)` / `Str.static()`.
--- Imports are metadata for the linker — they are stripped from the AST before
--- the later pipeline stages run, so no stage past the parser needs this node.

---@class ImportDecl: Stmt
---@field type "ImportDecl"
---@field segments string[]   Dotted path parts, in order; the last is the class name
---@field name string         Imported class name (the final segment / file stem)
---@field line integer | nil
---@field col  integer | nil
local ImportDecl = {}
ImportDecl.__index = ImportDecl

---@param segments string[]
---@param line? integer
---@param col?  integer
---@return ImportDecl
function ImportDecl.new(segments, line, col)
    return setmetatable(
        { type = "ImportDecl", segments = segments, name = segments[#segments], line = line, col = col },
        ImportDecl
    )
end

---@return string
function ImportDecl:__tostring()
    return ("ImportDecl(%s)"):format(table.concat(self.segments, "."))
end

return ImportDecl
