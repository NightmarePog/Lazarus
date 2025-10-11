local types = require("compiler.ast.ast_types")

local interface Declaration
   type: DataTypes
   value: any
end

local interface Variable 
   type: DataTypes
   value: Declaration | Function
end


local interface Function 
   scope: table
   parameters: {Declaration}
   return_type: DataTypes
end

local interface Extern
   value: Variable

end

local interface Return
   value: Variable | Declaration
end