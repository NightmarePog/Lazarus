--- Abstract interface for keyword-triggered statement parsers.
---
--- Each concrete statement (e.g. `private`) returns a `StatementParser` created
--- with `StatementParser.new`.  The dispatcher in `statements/init.lua`
--- collects these, builds a lookup table keyed by `keyword`, and calls
--- `handler.parse(parser)` when the matching token is seen.
---
--- **Contract**: when `parse` is called, the keyword token has already been
--- consumed by the dispatcher.  `parser:_current()` points at the token
--- immediately after the keyword.

---@class StatementParser
---@field keyword string         Token type that triggers this handler (e.g. `"PRIVATE"`)
---@field parse   fun(parser: Parser): Stmt
local StatementParser = {}

---@param keyword  string
---@param parse_fn fun(parser: Parser): Stmt
---@return StatementParser
function StatementParser.new(keyword, parse_fn)
    assert(type(keyword)   == "string",   "StatementParser.new: keyword must be a string")
    assert(type(parse_fn)  == "function", "StatementParser.new: parse must be a function")
    return { keyword = keyword, parse = parse_fn } --[[@as StatementParser]]
end

return StatementParser
