--- Linker tests.
---
--- The linker resolves a program's `import` graph into a flat, dependencies-first
--- module list. It takes a `read_file` callback, so these tests inject a virtual
--- filesystem (a path → source table) and never touch disk.

local Linker = require("linker")
local Error = require("error")

--- Build a `read_file(path)` over an in-memory `{ [path] = source }` table.
---@param files table<string, string?>
---@return fun(path: string): string | nil, string | nil
local function reader(files)
    return function(path)
        local src = files[path]
        if src then return src end
        return nil, "no such virtual file"
    end
end

--- Return the class names of `modules`, in order.
---@param modules { class_name: string }[]
---@return string[]
local function names(modules)
    local out = {}
    for _, m in ipairs(modules) do
        out[#out + 1] = m.class_name
    end
    return out
end

describe("Linker", function()
    it("links a single file with no imports", function()
        local modules, entry =
            Linker.link("src/Main.laz", reader({ ["src/Main.laz"] = "constructor() {}" }))
        assert.equal("Main", entry)
        assert.same({ "Main" }, names(modules))
        local main = modules[1]
        assert(main)
        assert.same({}, main.imports)
    end)

    it("strips import declarations out of the AST body", function()
        local modules = Linker.link(
            "src/Main.laz",
            reader({
                ["src/Main.laz"] = "import Box\nconstructor() {}",
                ["src/Box.laz"] = "constructor() {}",
            })
        )
        for _, m in ipairs(modules) do
            for _, node in ipairs(m.ast.body) do
                assert.is_not.equal("ImportDecl", node.type)
            end
        end
    end)

    it("orders dependencies before the classes that import them", function()
        local modules, entry = Linker.link(
            "src/Main.laz",
            reader({
                ["src/Main.laz"] = "import Box\nconstructor() {}",
                ["src/Box.laz"] = "constructor() {}",
            })
        )
        assert.equal("Main", entry)
        -- Box is a dependency of Main, so it must come first.
        assert.same({ "Box", "Main" }, names(modules))
        local main = modules[2]
        assert(main)
        assert.same({ "Box" }, main.imports)
    end)

    it("records a class only once for a diamond import", function()
        -- Main imports A and B; both import Shared. Shared is emitted once, first.
        local modules = Linker.link(
            "src/Main.laz",
            reader({
                ["src/Main.laz"] = "import A\nimport B\nconstructor() {}",
                ["src/A.laz"] = "import Shared\nconstructor() {}",
                ["src/B.laz"] = "import Shared\nconstructor() {}",
                ["src/Shared.laz"] = "constructor() {}",
            })
        )
        assert.same({ "Shared", "A", "B", "Main" }, names(modules))
    end)

    it("resolves a dotted path from the project root", function()
        local modules = Linker.link(
            "src/Main.laz",
            reader({
                ["src/Main.laz"] = "import math.Vec\nconstructor() {}",
                ["src/math/Vec.laz"] = "constructor() {}",
            })
        )
        -- The class name is the final segment; the folders locate the file.
        assert.same({ "Vec", "Main" }, names(modules))
    end)

    it("tolerates a cyclic import without looping forever", function()
        local modules = Linker.link(
            "src/A.laz",
            reader({
                ["src/A.laz"] = "import B\nconstructor() {}",
                ["src/B.laz"] = "import A\nconstructor() {}",
            })
        )
        -- A→B→A: the back-edge to A is cut by the cycle guard, so B completes
        -- first. Both are linked exactly once and the loader does not hang.
        assert.same({ "B", "A" }, names(modules))
    end)

    it("raises a SEMANTIC_ERROR for an unresolved import", function()
        local ok, err = pcall(
            function()
                Linker.link(
                    "src/Main.laz",
                    reader({
                        ["src/Main.laz"] = "import Missing\nconstructor() {}",
                    })
                )
            end
        )
        assert.is_false(ok)
        assert.equal(Error.Type.SEMANTIC_ERROR, (err --[[@as Error]]).type)
        assert.matches("Cannot resolve import", (err --[[@as Error]]).message)
    end)

    it("resolves dotted imports from the project root, not the importing file", function()
        -- A nested file (src/pkg/A.laz) importing `pkg.B` resolves from the root
        -- (src/pkg/B.laz), NOT relative to the importer (which would be src/pkg/pkg/B).
        local modules = Linker.link(
            "src/Main.laz",
            reader({
                ["src/Main.laz"] = "import pkg.A\nconstructor() {}",
                ["src/pkg/A.laz"] = "import pkg.B\nconstructor() {}",
                ["src/pkg/B.laz"] = "constructor() {}",
            })
        )
        assert.same({ "B", "A", "Main" }, names(modules))
    end)
end)
