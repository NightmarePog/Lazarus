--- Statement-fold dispatcher: maps each statement node type to its rule.
---
--- To add a rule, create a `FoldStatement` module and list it in `HANDLERS`;
--- the registry is built automatically. The driver lives in `optimizer/init.lua`.

---@type FoldStatement[]
local HANDLERS = {
    (require("frontend.optimizer.statements.variable")),
    (require("frontend.optimizer.statements.function")),
    (require("frontend.optimizer.statements.constructor")),
    (require("frontend.optimizer.statements.return")),
    (require("frontend.optimizer.statements.expression")),
    (require("frontend.optimizer.statements.field_assign")),
    (require("frontend.optimizer.statements.if")),
    (require("frontend.optimizer.statements.while")),
    (require("frontend.optimizer.statements.loop")),
    (require("frontend.optimizer.statements.for")),
}

---@type table<string, FoldStatement>
local registry = {}
for _, handler in ipairs(HANDLERS) do
    registry[handler.type] = handler
end

return registry
