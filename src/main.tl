package.path = package.path .. ";./build/?.lua;"
local file_read = require("compiler.load_data")
local lexer = require("compiler.lexer")
local ast = require("compiler.ast")
local utils = require("utils")

local function main()
    -- checks if arg 1 exists
    if not arg[1] then
        error("no path parameter found")
        return
    end

    -- tries to read
    local result, err = file_read.read_file(arg[1])
    if err then
        -- failed not found
        print("file not found on path "..arg[1])
    end

    -- lexer
    local tokenized_code = lexer.tokenize(result)
    local tokenized_code_with_types = lexer.lex_check(tokenized_code)
    utils.map(tokenized_code_with_types, function(_, v: TokenTypes)
        lexer.print_token_type(v)
    end)
    print("lexer success")
    -- parser
    ast.parse(tokenized_code_with_types) 
end

main()