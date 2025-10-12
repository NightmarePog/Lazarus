-- file_reader.lua
local module = {}

--- Reads the entire content of a file
-- @param filename string: path to the file
-- @return string content or nil, string error message
function module.read_file(filename: string): (nil | string, nil | string)
    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()
    return content, nil
end

return module
