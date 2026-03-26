-- src/frontend/parser/nodes.lua
local ASTNodes = {}

function ASTNodes.ident(name)
    return { type = "IDENT", value = name }
end

function ASTNodes.extends(extending)
    return { type = "EXTENDS", value = extending }
end

function ASTNodes.variable(constant, privacy)
    return { type = "VARIABLE", constant = constant, privacy = privacy }
end

function ASTNodes.funcDecl(name, params, body)
    return { type = "FUNC_DECL", name = name, params = params or {}, body = body or {} }
end

function ASTNodes.call(name, args)
    return { type = "CALL", name = name, args = args or {} }
end

function ASTNodes.classConstructorCall(class, args)
    return { type = "NEW", class = class, args = args or {} }
end

function ASTNodes.number(value)
    return { type = "NUMBER", value = value }
end

function ASTNodes.string(value)
    return { type = "STRING", value = value }
end

function ASTNodes.block(body)
    return { type = "BLOCK", body = body or {} }
end

function ASTNodes.assign(target, value)
    return { type = "ASSIGN", target = target, value = value }
end

function ASTNodes.luaBlock(value)
    return { type = "LUA_BLOCK", value = value }
end

function ASTNodes.import(module)
    return { type = "IMPORT", module = module }
end

function ASTNodes.forLoop(iterator, range, body)
    return { type = "FOR_LOOP", iterator = iterator, range = range, body = body or {} }
end

function ASTNodes.binaryOp(op, left, right)
    return { type = op, left = left, right = right }
end

return ASTNodes
