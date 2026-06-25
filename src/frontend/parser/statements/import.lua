--- Statement handler for `import` — declares a dependency on another class.
---
--- Form: `import seg.seg.Class` — a dot-separated path resolved from the project
--- root (the directory of the entry file). The final segment is the class name
--- (and the file stem); the leading segments are folders. There is no relative
--- (`../`) form and no quoted-path form — every import is project-root-relative.
--- e.g. `import std.Str` -> `<root>/std/Str.laz`, used qualified as `Str`.

local StatementParser = require("frontend.parser.statements.statement_parser")
local ImportDecl = require("frontend.parser.nodes.import")

return StatementParser.new("IMPORT", function(parser)
    local keyword = parser:_previous() --[[@as Token]]

    local first = parser:_consume("IDENTIFIER", "Expected a name after 'import'")
    local segments = { first.value }
    while parser:_match("DOT") do
        local seg = parser:_consume("IDENTIFIER", "Expected a name after '.' in an import path")
        segments[#segments + 1] = seg.value
    end

    return ImportDecl.new(segments, keyword.line, keyword.column)
end)
