-- file_reader.lua
local module = {}

--- Reads the entire content of a file
-- @param filename string: path to the file
-- @return string content or nil, string error message
function module.read_file(filename)

    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()
    return content
end

return module
