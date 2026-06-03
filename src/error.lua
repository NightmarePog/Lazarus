local Error = {}

Error.Type = {
    UNEXPECTED_CHAR = "UNEXPECTED_CHAR",
    UNTERMINATED_STRING = "UNTERMINATED_STRING",
    INVALID_NUMBER = "INVALID_NUMBER",
    UNEXPECTED_EOF = "UNEXPECTED_EOF",
    UNEXPECTED_TOKEN = "UNEXPECTED_TOKEN",
    SYNTAX_ERROR = "SYNTAX_ERROR"
}

local function format_message(err)
    local loc = ""
    if err.line and err.col then loc = ("(%d:%d) "):format(err.line, err.col) end

    return loc .. err.type .. ": " .. err.message
end

function Error.new(err_type, message, line, col)
    return setmetatable({
        type = err_type,
        message = message,
        line = line,
        col = col
    },
        {
            __tostring = format_message
        })
end

function Error.throw(err_type, message, line, col)
    error(tostring(Error.new(err_type, message, line, col)))
end

function Error.format(err)
    return tostring(err)
end

return Error
