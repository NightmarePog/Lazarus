local tokensLib = require("compiler.tokens_lib")
local module = {}

function module.tokenize(code)
    local tokens = {}
    local current = ""
    local in_string = false

    code = code:gsub("/%*.-%*/", "")
    code = code:gsub("//[^\n]*", "")

    local function addToken()
        if #current > 0 then
            table.insert(tokens, current)
            current = ""
        end
    end

    local i = 1
    while i <= #code do
        local ch = code:sub(i, i)
        local nextCh = code:sub(i + 1, i + 1)
        local twoChar = ch .. nextCh

        if in_string then
            current = current .. ch
            if ch == '"' then
                in_string = false
                addToken()
            end

        else
            if ch == '"' then
                addToken()
                in_string = true
                current = ch

            elseif ch:match("[%w_]") then
                current = current .. ch

            else
                addToken()

                -- compound operator check
                if tokensLib.compoundOperators[twoChar] then
                    table.insert(tokens, twoChar)
                    i = i + 1 -- skip next char
                elseif not ch:match("%s") then
                    table.insert(tokens, ch)
                end
            end
        end

        i = i + 1
    end

    for _, value in ipairs(tokens) do
        print(value)
    end
    addToken()
    return tokens
end


local function token_type(token)
    local tokenType = tokensLib.getTokenType(token)

    if tokenType then
        return { type = tokenType, value = token }
    elseif token:match('^".*"$') then
        return { type = "string", value = token:sub(2, -2) }
    elseif tonumber(token) then
        return { type = "number", value = tonumber(token) }
    elseif token:match("^[%a_][%w_]*$") then
        return { type = "identifier", value = token }
    else
        return { type = "unknown", value = token }
    end
end

local function print_token_type(token_type) 
    print("TYPE: ".. token_type["type"].. ", VALUE: ".. token_type["value"] )
end

function module.lex(code_tokens)
    local typed_tokens = {}
    for _, token in ipairs(code_tokens) do
        local found = false

        if tokensLib.getTokenType(token) then
            found = true
        elseif token:match('^".*"$') then
            found = true -- string literal
        elseif tonumber(token) then
            found = true -- number
        elseif token:match("^[%a_][%w_]*$") then
            found = true -- var, func, class etc
        end

        if not found then
            error("unknown token: " .. token)
        end
        table.insert(typed_tokens, token_type(token))
        print_token_type(token_type(token))
    end
end


return module
