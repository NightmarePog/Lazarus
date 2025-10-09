--- AST Boilerplate for Lazarus
-- Provides functions to create AST nodes for the Lazarus language.
-- @module AST

local AST = {}

--- Creates a generic AST node.
-- @param type string Type of the node (e.g., "variable_declaration")
-- @param props table Optional properties for the node
-- @return table AST node
local function createNode(type, props)
    local node = { type = type }
    if props then
        for k, v in pairs(props) do
            node[k] = v
        end
    end
    return node
end

--- Creates a variable declaration node.
-- @param varType string Variable type ("number", "string", "boolean", "class", etc.)
-- @param name string Variable name
-- @param value table AST node representing the initial value
-- @return table AST node
function AST.variableDeclaration(varType, name, value)
    return createNode("variable_declaration", {
        varType = varType,
        name = name,
        value = value
    })
end

--- Creates an assignment node.
-- @param target string Variable name to assign to
-- @param value table AST node representing the value
-- @return table AST node
function AST.assignment(target, value)
    return createNode("assignment", {
        target = target,
        value = value
    })
end

--- Creates a binary expression node.
-- @param operator string Operator ("+", "-", "*", "/", etc.)
-- @param left table Left operand (AST node)
-- @param right table Right operand (AST node)
-- @return table AST node
function AST.binaryExpression(operator, left, right)
    return createNode("binary_expression", {
        operator = operator,
        left = left,
        right = right
    })
end

--- Creates a unary expression node.
-- @param operator string Operator ("-", "!", etc.)
-- @param operand table Operand AST node
-- @return table AST node
function AST.unaryExpression(operator, operand)
    return createNode("unary_expression", {
        operator = operator,
        operand = operand
    })
end

--- Creates an if statement node.
-- @param condition table AST node for the condition
-- @param thenBody table AST block executed if condition is true
-- @param elseBody table AST block executed if condition is false (optional)
-- @return table AST node
function AST.ifStatement(condition, thenBody, elseBody)
    return createNode("if_statement", {
        condition = condition,
        thenBody = thenBody,
        elseBody = elseBody
    })
end

--- Creates a while loop node.
-- @param condition table AST node for the loop condition
-- @param body table AST block representing the loop body
-- @return table AST node
function AST.whileLoop(condition, body)
    return createNode("while_loop", {
        condition = condition,
        body = body
    })
end

--- Creates a for loop node.
-- @param init table AST node for initialization (e.g., number i = 0)
-- @param condition table AST node for loop condition
-- @param increment table AST node for loop increment
-- @param body table AST block for loop body
-- @return table AST node
function AST.forLoop(init, condition, increment, body)
    return createNode("for_loop", {
        init = init,
        condition = condition,
        increment = increment,
        body = body
    })
end

--- Creates a function declaration node.
-- @param name string Function name
-- @param params table List of parameters, each as {name="x", type="number"}
-- @param body table AST block representing the function body
-- @return table AST node
function AST.functionDeclaration(name, params, body)
    return createNode("function_declaration", {
        name = name,
        params = params,
        body = body
    })
end

--- Creates a function call node.
-- @param name string Function name
-- @param arguments table List of AST nodes as arguments
-- @return table AST node
function AST.functionCall(name, arguments)
    return createNode("function_call", {
        name = name,
        arguments = arguments
    })
end

--- Creates a return statement node.
-- @param value table AST node representing the returned value
-- @return table AST node
function AST.returnStatement(value)
    return createNode("return_statement", { value = value })
end

--- Creates a block node.
-- @param statements table List of AST nodes representing statements
-- @return table AST node
function AST.block(statements)
    return createNode("block", { statements = statements })
end

--- Creates an import statement node.
-- @param module string Module name
-- @return table AST node
function AST.importStatement(module)
    return createNode("import_statement", { module = module })
end

--- Creates an export statement node.
-- @param declaration table AST node of the declaration to export
-- @return table AST node
function AST.exportStatement(declaration)
    return createNode("export_statement", { declaration = declaration })
end

--- Creates a class declaration node.
-- @param name string Class name
-- @param body table List of AST nodes representing class members
-- @return table AST node
function AST.classDeclaration(name, body)
    return createNode("class_declaration", { name = name, body = body })
end

--- Creates a class property (field) node.
-- @param access string Access level ("public" or "private")
-- @param name string Field name
-- @param varType string Type of the field
-- @param value table AST node for the initial value (optional)
-- @return table AST node
function AST.classProperty(access, name, varType, value)
    return createNode("class_property", {
        access = access,
        name = name,
        varType = varType,
        value = value
    })
end

--- Creates a class method node.
-- @param access string Access level ("public" or "private")
-- @param name string Method name
-- @param params table List of parameters {name="x", type="number"}
-- @param body table AST block of method body
-- @return table AST node
function AST.classMethod(access, name, params, body)
    return createNode("class_method", {
        access = access,
        name = name,
        params = params,
        body = body
    })
end

--- Creates a class constructor node.
-- @param params table List of parameters
-- @param body table AST block of constructor body
-- @return table AST node
function AST.classConstructor(params, body)
    return createNode("class_constructor", { params = params, body = body })
end

--- Creates a class instantiation node.
-- @param className string Name of the class
-- @param instanceName string Name of the instance variable
-- @param arguments table List of AST nodes as constructor arguments
-- @return table AST node
function AST.classInstantiation(className, instanceName, arguments)
    return createNode("class_instantiation", {
        className = className,
        instanceName = instanceName,
        arguments = arguments
    })
end

--- Creates a method call node.
-- @param instance string Name of the instance
-- @param method string Method name
-- @param arguments table List of AST nodes as arguments
-- @return table AST node
function AST.methodCall(instance, method, arguments)
    return createNode("method_call", {
        instance = instance,
        method = method,
        arguments = arguments
    })
end

--- Creates a literal node.
-- @param value any Literal value
-- @param literalType string Type of literal ("number", "string", "boolean", "nil")
-- @return table AST node
function AST.literal(value, literalType)
    return createNode("literal", { value = value, literalType = literalType })
end

--- Creates an identifier node.
-- @param name string Identifier name
-- @return table AST node
function AST.identifier(name)
    return createNode("identifier", { value = name })
end

return AST
