local Error = require("error")

describe("Error", function ()
    describe("Error.new", function ()
        it("stores type, message, line, col", function ()
            local e = Error.new(Error.Type.UNEXPECTED_CHAR, "bad char", 3, 7)
            assert.equal(Error.Type.UNEXPECTED_CHAR, e.type)
            assert.equal("bad char", e.message)
            assert.equal(3, e.line)
            assert.equal(7, e.col)
        end)

        it("formats with location when line and col are present", function ()
            local e = Error.new(Error.Type.UNEXPECTED_CHAR, "bad char", 2, 5)
            local s = tostring(e) --[[@as string]]
            -- Matches the new "file:line:col" location syntax within the text block
            assert.matches("Location: .-:2:5", s)
            assert.matches("UNEXPECTED_CHAR", s)
            assert.matches("bad char", s)
        end)

        it("handles completely missing location info gracefully", function ()
            -- Bypass Error.new auto-detection to explicitly test the 'unknown' fallback
            local e = setmetatable({
                type = Error.Type.INVALID_NUMBER,
                message = "not a number"
            }, Error)

            local s = Error.format(e)
            assert.matches("INVALID_NUMBER", s)
            assert.matches("not a number", s)
            assert.matches("Location: unknown", s)
        end)
    end)

    describe("Error.throw", function ()
        it("raises a Lua error", function ()
            assert.has_error(function ()
                Error.throw(Error.Type.UNEXPECTED_CHAR, "!")
            end)
        end)

        it("error message contains the error type", function ()
            local ok, err_obj = pcall(function ()
                Error.throw(Error.Type.UNTERMINATED_STRING, "missing quote", 1, 4)
            end)
            assert.is_false(ok)

            -- pcall returns the raw table object, so we stringify it to test the output
            local msg = tostring(err_obj)
            assert.matches("UNTERMINATED_STRING", msg)
            assert.matches("missing quote", msg)
        end)
    end)

    describe("Error.format", function ()
        it("is contained within the tostring output", function ()
            local e = Error.new(Error.Type.INVALID_NUMBER, "nan", 1, 1)
            local s = tostring(e) --[[@as string]]
            local expected_format = Error.format(e)

            -- Verifies that tostring(e) begins with the formatted box block
            assert.equal(expected_format, s:sub(1, #expected_format))
        end)
    end)

    describe("Error.Type constants", function ()
        it("defines UNEXPECTED_CHAR", function ()
            assert.equal("UNEXPECTED_CHAR", Error.Type.UNEXPECTED_CHAR)
        end)

        it("defines UNTERMINATED_STRING", function ()
            assert.equal("UNTERMINATED_STRING", Error.Type.UNTERMINATED_STRING)
        end)

        it("defines INVALID_NUMBER", function ()
            assert.equal("INVALID_NUMBER", Error.Type.INVALID_NUMBER)
        end)
    end)
end)
