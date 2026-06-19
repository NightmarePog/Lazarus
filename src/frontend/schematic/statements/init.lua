--- Statement-check dispatcher: maps each statement node type to its rule.
---
--- To add a rule, create a `StatementCheck` module and list it in `HANDLERS`;
--- the registry is built automatically. The driver lives in `schematic/init.lua`.

---@type StatementCheck[]
local HANDLERS = {
    (require("frontend.schematic.statements.variable")),
    (require("frontend.schematic.statements.function")),
    (require("frontend.schematic.statements.return")),
    (require("frontend.schematic.statements.expression")),
    (require("frontend.schematic.statements.if")),
    (require("frontend.schematic.statements.while")),
    (require("frontend.schematic.statements.loop")),
    (require("frontend.schematic.statements.for")),
    (require("frontend.schematic.statements.break")),
}

---@type table<string, StatementCheck>
local registry = {}
for _, handler in ipairs(HANDLERS) do
    registry[handler.type] = handler
end

return registry
