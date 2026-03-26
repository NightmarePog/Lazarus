-- src/frontend/parser/parser.lua
local ASTNodes = require("frontend.parser.nodes")

local parser = {}

-- interní stav parseru
local tokens, pos

local function peek()
    return tokens[pos]
end

local function next()
    local t = tokens[pos]
    pos = pos + 1
    return t
end

-- parse jednotlivého statementu
local function parseStatement()
    local tok = peek()

    if not tok then return nil end

    -- extends Base
    if tok.type == "EXTENDS" then
        next()                 -- EXTENDS
        local nameTok = next() -- IDENT
        return ASTNodes.extends(nameTok.value)

        -- func <name>() { ... }
    elseif tok.type == "FUNC" then
        next()                 -- FUNC
        local nameTok = next() -- IDENT
        next()                 -- LPAREN
        local params = {}
        while peek() and peek().type ~= "RPAREN" do
            table.insert(params, next().value)
            if peek() and peek().type == "COMMA" then next() end
        end
        next() -- RPAREN
        next() -- LBRACE
        local body = {}
        while peek() and peek().type ~= "RBRACE" do
            table.insert(body, parseStatement())
        end
        next() -- RBRACE
        return ASTNodes.funcDecl(nameTok.value, params, body)

        -- public/private <name> { ... }
    elseif tok.type == "PUBLIC" or tok.type == "PRIVATE" then
        local privacyTok = next()
        local nameTok = next() -- IDENT
        next()                 -- LBRACE
        local body = {}
        while peek() and peek().type ~= "RBRACE" do
            local inner = peek()
            if inner.type == "LUA_BLOCK" then
                table.insert(body, ASTNodes.luaBlock(next().value))
            else
                table.insert(body, parseStatement())
            end
        end
        next() -- RBRACE
        return ASTNodes.variable(false, privacyTok.type:lower(), nameTok.value, body)

        -- volání funkce: IDENT(args)
    elseif tok.type == "IDENT" and tokens[pos + 1] and tokens[pos + 1].type == "LPAREN" then
        local nameTok = next()
        next() -- LPAREN
        local args = {}
        while peek() and peek().type ~= "RPAREN" do
            table.insert(args, parseStatement())
            if peek() and peek().type == "COMMA" then next() end
        end
        next() -- RPAREN
        return ASTNodes.call(nameTok.value, args)

        -- čísla
    elseif tok.type == "NUMBER" then
        next()
        return ASTNodes.number(tok.value)

        -- stringy
    elseif tok.type == "STRING" then
        next()
        return ASTNodes.string(tok.value)

        -- lua block
    elseif tok.type == "LUA_BLOCK" then
        next()
        return ASTNodes.luaBlock(tok.value)
    else
        -- fallback ident
        next()
        return ASTNodes.string(tok.value)
    end
end

-- parse celého programu
function parser.parseProgram(toks)
    tokens = toks
    pos = 1
    local body = {}

    while pos <= #tokens do
        local stmt = parseStatement()
        if stmt then
            table.insert(body, stmt)
        else
            pos = pos + 1
        end
    end

    return ASTNodes.block(body)
end

return parser
