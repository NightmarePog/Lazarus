
local types = {}

-- all possible variable data types
global type DataTypes = enum
   "number"
   "string"
   "bool"
   "undefined"
   "func"
   "variable"
   "identifier"
end

-- all possible operations
global type Operations = enum
   "plus" "minus" "times" "divide" "modulo" "power" "floor_div"
   "equal" "not_equal" "less_than" "less_equal" "greater_than" "greater_equal"
   "and_op" "or_op" "concat"
   "not"
   "literal"
end

-- type and assinged operations
global type_operations = {
    number: {Operations} = {
        "plus",
        "minus",
        "times",
        "divide",
        "modulo",
        "power",
        "floor_div",
        "equal",
        "not_equal",
        "less_than",
        "less_equal",
        "greater_than",
        "greater_equal",
        "and_op",
        "or_op"
    },
    string: {Operations} = {
        "concat",
        "equal",
        "not_equal",
        "less_than",
        "equal",
        "greater_equal",
        "greater_than",
        "literal"
    },
    bool: {Operations}  = {
        "and_op",
        "or_op",
        "equal",
        "not_equal",
        "not",
        "literal"
    },
    undefined: {Operations}  = {
        "equal",
        "not",
        "literal",
    },
    func: {Operations}  = {
        "equal",
        "not",
        "literal",
    }
}


-- AST abstract node
global interface Node 
   node_type: string
end

-- Declaration node
-- 5, true, "hi"
global interface NodeDeclaration is Node
   where self.node_type == "Declaration"
   type: DataTypes
   value: any
end

-- Variable node
-- let main;, let num
global interface NodeVariable is Node
   where self.node_type == "Variable"
   type: DataTypes
   value: NodeDeclaration | NodeFunction
end

-- Function Node
-- (), () =>
global interface NodeFunction is Node
   where self.node_type == "Function"
   scope: table
   parameters: {NodeDeclaration}
   return_type: DataTypes
end

-- Extern Node
-- extern ...
global interface NodeExtern is Node
   where self.node_type == "Extern"
   value: NodeVariable

end

-- Return node
-- return ...
global interface NodeReturn is  Node
   where self.node_type == "Return"
   value: NodeVariable | NodeDeclaration
end

-- functionCall Node
-- func(), func(a, b)
global interface FunctionCall is Node
   where self.node_type == "FunctionCall"
   parameters: NodeVariable | NodeDeclaration
end

-- ASTRoot
-- root node of whole program
global interface ASTRoot is Node
   where self.node_type == "ASTRoot"
   body: {Node}
end

-- {string} but typed for Tokens for better readability
global type Tokens = {string}

return types