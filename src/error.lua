--- Error type, formatting, and throw utilities for the Lazarus interpreter.
---
--- All runtime errors are represented as `Error` objects so they carry source
--- position and can render a source-code snippet with a caret pointing at the
--- offending token.

---@class Error
---@field type    string        Error kind constant (see `Error.Type`)
---@field message string        Human-readable description
---@field line    integer | nil Line in the *user's* source where the error occurred
---@field col     integer | nil Column in the *user's* source where the error occurred
---@field source  string | nil  Full source text — used to render the inline snippet
---@field span    integer | nil Number of source characters to underline (default 1)
local Error = {}
Error.__index = Error

---@type table<string, string>
local Color = { RED = "\27[31m", GRAY = "\27[90m", BOLD = "\27[1m", RESET = "\27[0m" }

---@enum ErrorType
Error.Type = {
    UNEXPECTED_CHAR     = "UNEXPECTED_CHAR",
    UNTERMINATED_STRING = "UNTERMINATED_STRING",
    INVALID_NUMBER      = "INVALID_NUMBER",
    UNEXPECTED_EOF      = "UNEXPECTED_EOF",
    UNEXPECTED_TOKEN    = "UNEXPECTED_TOKEN",
    SYNTAX_ERROR        = "SYNTAX_ERROR",
    SEMANTIC_ERROR      = "SEMANTIC_ERROR",
}

--- Construct a new Error value. All positional fields are optional; when
--- `source` is provided the formatted output will include an inline snippet.
---@param err_type string
---@param message  string
---@param line     integer | nil
---@param col      integer | nil
---@param source   string | nil
---@param span     integer | nil
---@return Error
function Error.new(err_type, message, line, col, source, span)
    return setmetatable({
        type    = err_type,
        message = message,
        line    = line,
        col     = col,
        source  = source,
        span    = span or 1,
    }, Error)
end

---@return string
function Error:__tostring()
    -- The internal Lua stack trace is debugging output for *compiler*
    -- developers, not for users of the Lazarus language. Only append it when
    -- `LAZARUS_DEBUG` is set so end users see a clean diagnostic box.
    if os.getenv("LAZARUS_DEBUG") then
        return Error.format(self) .. Error.traceback(4)
    end
    return Error.format(self)
end

--- Create an Error and immediately raise it via `error()`.  This function
--- never returns; annotated `---@noreturn` so the type-checker can narrow
--- types in code that follows a guarded call.
---@param err_type string
---@param message  string
---@param line     integer | nil
---@param col      integer | nil
---@param source   string | nil
---@param span     integer | nil
---@noreturn
function Error.throw(err_type, message, line, col, source, span)
    error(Error.new(err_type, message, line, col, source, span), 2)
end

--- Format the location portion of the error header (`"unknown:line:col"`).
---@param err Error
---@return string
local function format_location(err)
    if err.line and err.col then
        return string.format("unknown:%d:%d", err.line, err.col)
    elseif err.line then
        return string.format("unknown:%d", err.line)
    end
    return "unknown"
end

--- Count the display width (number of UTF-8 codepoints) of `s`.
--- Continuation bytes (`10xxxxxx`) are skipped so that a multibyte glyph such
--- as `│` counts as one column rather than its byte length — keeping caret
--- alignment correct regardless of the box-drawing characters in the prefix.
---@param s string
---@return integer
local function display_width(s)
    local width = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then width = width + 1 end
    end
    return width
end

--- Extract a single line from `source` by 1-based line number.
---@param source      string
---@param target_line integer
---@return string | nil
local function get_source_line(source, target_line)
    local n = 0
    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        if n == target_line then return line end
    end
    return nil
end

--- Build the source-snippet lines (code line + caret line) for `err`.
--- Returns an empty table when the error lacks position or source text.
---@param err Error
---@return string[]
local function format_snippet(err)
    ---@type string[]
    local lines = {}

    if not err.source or not err.line then return lines end

    local src_line = get_source_line(err.source, err.line)
    if not src_line then return lines end

    local line_prefix = string.format("   %d │ ", err.line)
    lines = { "│ " .. line_prefix .. src_line }

    if err.col then
        local inner_pad = string.rep(" ", display_width(line_prefix) + err.col - 1)
        local carets    = Color.RED .. string.rep("^", math.max(1, err.span or 1)) .. Color.RESET
        lines[#lines + 1] = "│ " .. inner_pad .. carets
    end

    return lines
end

--- Render `err` as a coloured box string.  Does *not* include the stack
--- trace; see `Error.traceback` for that.
---@param err Error
---@return string
function Error.format(err)
    local location = format_location(err)
    local snippet  = format_snippet(err)

    local lines = {
        "",
        Color.RED .. "╭─ Error ──────────────────────────────" .. Color.RESET,
        "│ Type: " .. Color.BOLD .. (err.type or "UNKNOWN") .. Color.RESET,
        "│ Location: " .. location,
        "│",
        "│ " .. (err.message or ""),
    }

    if #snippet > 0 then
        lines[#lines + 1] = "│"
        for _, l in ipairs(snippet) do
            lines[#lines + 1] = l
        end
    end

    lines[#lines + 1] = Color.RED .. "╰──────────────────────────────────────" .. Color.RESET
    lines[#lines + 1] = ""

    return table.concat(lines, "\n")
end

--- Collect Lua stack frames starting at `start_level`, filtering out
--- internal error-handling frames, and return a formatted traceback string.
---@param start_level integer | nil
---@return string
---@nodiscard
function Error.traceback(start_level)
    start_level = start_level or 3
    local out = {}

    for i = start_level, math.huge --[[@as integer]] do
        local info = debug.getinfo(i, "nSl")
        if not info then break end

        local name = info.name or "<anonymous>"
        local src  = info.short_src or "?"
        local line = info.currentline or 0

        if name ~= "throw" and name ~= "error" and not src:match("error%.lua$") then
            out[#out + 1] = string.format("  • %s (%s:%d)", name, src, line)
        end
    end

    if #out == 0 then return "" end

    return "\n" .. Color.GRAY .. "Stack trace" .. Color.RESET
        .. "\n\n" .. Color.GRAY .. table.concat(out, "\n") .. Color.RESET .. "\n"
end

return Error
