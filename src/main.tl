package.path = package.path .. ";./build/?.lua;"
local file_read = require("compiler.load_data")
local lexer = require("compiler.lexer")

local function main()
    if not arg[1] then
        error("no path parameter found")
        return
    end

    local result, err = file_read.read_file(arg[1])
    if err then
        error("failed to compile - file not found")
        if arg[1] then
            print("file not found on path "..arg[1])
        end
    end
    local tokenized_code = lexer.tokenize(result)
    lexer.lex(tokenized_code)
    print("lexer success")

    
end

main()