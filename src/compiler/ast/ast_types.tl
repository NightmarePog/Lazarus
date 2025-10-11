
local ast_types = {}

global type DataTypes = enum
   "number"
   "string"
   "bool"
   "undefined"
   "func"
   "variable"
end

global type Operations = enum
   "plus" "minus" "times" "divide" "modulo" "power" "floor_div"
   "equal" "not_equal" "less_than" "less_equal" "greater_than" "greater_equal"
   "and_op" "or_op" "concat"
   "not"
   "literal"
end

global type_binary_ops = {
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


return ast_types