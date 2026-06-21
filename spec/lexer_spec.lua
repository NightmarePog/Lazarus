local Lexer = require("frontend.lexer")
local Token = require("frontend.lexer.token")
local Error = require("error")

local function scan(source) return Lexer.new(source):scan() end

local function tok(tokens, i) return tokens[i] end

describe("Lexer", function()
    describe("Token structure", function()
        it("returns a table with type, value, line, column", function()
            local t = Token.new("PRIVATE", "private", 1, 1)
            assert.equal("PRIVATE", t.type)
            assert.equal("private", t.value)
            assert.equal(1, t.line)
            assert.equal(1, t.column)
        end)

        it("__tostring formats correctly", function()
            local t = Token.new("NUMBER", "42", 3, 7, 42)
            assert.equal("Token(NUMBER, 42, 3:7)", tostring(t))
        end)
    end)

    describe("empty / whitespace input", function()
        it("returns no tokens for empty string", function() assert.same({}, scan("")) end)

        it(
            "returns no tokens for whitespace-only input",
            function() assert.same({}, scan("   \t\n  ")) end
        )
    end)

    describe("keywords", function()
        it("tokenises 'private' as PRIVATE", function()
            local tokens = scan("private")
            assert.equal(1, #tokens)
            assert.equal("PRIVATE", tok(tokens, 1).type)
            assert.equal("private", tok(tokens, 1).value)
        end)

        it("keyword tokens have nil literal", function()
            local tokens = scan("private")
            assert.is_nil(tok(tokens, 1).literal)
        end)
    end)

    describe("constructor keyword", function()
        it("tokenises 'constructor' as CONSTRUCTOR", function()
            local tokens = scan("constructor")
            assert.equal(1, #tokens)
            assert.equal("CONSTRUCTOR", tok(tokens, 1).type)
        end)
    end)

    describe("identifiers", function()
        it("tokenises a plain name as IDENTIFIER", function()
            local tokens = scan("foo")
            assert.equal(1, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
            assert.equal("foo", tok(tokens, 1).value)
        end)

        it("stores identifier name in literal", function()
            local tokens = scan("foo")
            assert.equal("foo", tok(tokens, 1).literal)
        end)

        it("tokenises underscore-prefixed names", function()
            local tokens = scan("_bar")
            assert.equal(1, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
        end)

        it("tokenises names with digits after the first char", function()
            local tokens = scan("x1y2")
            assert.equal(1, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
            assert.equal("x1y2", tok(tokens, 1).value)
        end)

        it("throws INVALID_NUMBER when a letter immediately follows a number literal", function()
            local ok, err = pcall(function() scan("1foo") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.INVALID_NUMBER, err.type)
        end)
    end)

    describe("numbers", function()
        it("tokenises a single digit", function()
            local tokens = scan("7")
            assert.equal(1, #tokens)
            assert.equal("NUMBER", tok(tokens, 1).type)
            assert.equal(7, tok(tokens, 1).literal)
        end)

        it("tokenises a multi-digit integer", function()
            local tokens = scan("1234")
            assert.equal(1, #tokens)
            assert.equal(1234, tok(tokens, 1).literal)
        end)

        it("stores the raw string in value and the number in literal", function()
            local tokens = scan("99")
            assert.equal("99", tok(tokens, 1).value)
            assert.equal(99, tok(tokens, 1).literal)
        end)

        it("throws INVALID_NUMBER when a letter immediately follows a number", function()
            local ok, err = pcall(function() scan("123abc") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.INVALID_NUMBER, err.type)
            assert.matches("after number literal", err.message)
        end)

        it("tokenises a float literal", function()
            local tokens = scan("3.14")
            assert.equal(1, #tokens)
            assert.equal("NUMBER", tok(tokens, 1).type)
            assert.equal("3.14", tok(tokens, 1).value)
            assert.equal(3.14, tok(tokens, 1).literal)
        end)

        it("does not consume a '.' that is not followed by a digit", function()
            -- `3.` is the integer 3 followed by a separate DOT (field-access) token.
            local tokens = scan("3.")
            assert.equal(2, #tokens)
            assert.equal("NUMBER", tok(tokens, 1).type)
            assert.equal(3, tok(tokens, 1).literal)
            assert.equal("DOT", tok(tokens, 2).type)
        end)
    end)

    describe("string literals", function()
        it("tokenises a simple string as STRING", function()
            local tokens = scan('"hello"')
            assert.equal(1, #tokens)
            assert.equal("STRING", tok(tokens, 1).type)
        end)

        it("stores the content without quotes in literal", function()
            local tokens = scan('"hello"')
            assert.equal("hello", tok(tokens, 1).literal)
        end)

        it("stores the raw source text with quotes in value", function()
            local tokens = scan('"hello"')
            assert.equal('"hello"', tok(tokens, 1).value)
        end)

        it("handles an empty string", function()
            local tokens = scan('""')
            assert.equal(1, #tokens)
            assert.equal("STRING", tok(tokens, 1).type)
            assert.equal("", tok(tokens, 1).literal)
        end)

        it("records the correct start position", function()
            local tokens = scan('"hi"')
            assert.equal(1, tok(tokens, 1).line)
            assert.equal(1, tok(tokens, 1).column)
        end)

        it("throws UNTERMINATED_STRING for an unclosed string", function()
            local ok, err = pcall(function() scan('"hello') end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNTERMINATED_STRING, err.type)
        end)

        it("throws UNTERMINATED_STRING when a newline appears inside the string", function()
            local ok, err = pcall(function() scan('"hello\nworld"') end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNTERMINATED_STRING, err.type)
        end)

        it("reports the opening-quote column in UNTERMINATED_STRING", function()
            local ok, err = pcall(function() scan('   "oops') end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(4, err.col)
        end)
    end)

    describe("symbols", function()
        it("tokenises '=' as ASSIGN", function()
            local tokens = scan("=")
            assert.equal(1, #tokens)
            assert.equal("ASSIGN", tok(tokens, 1).type)
        end)

        it("tokenises '+' as PLUS", function()
            local tokens = scan("+")
            assert.equal("PLUS", tok(tokens, 1).type)
        end)

        it("tokenises '-' as MINUS", function()
            local tokens = scan("-")
            assert.equal("MINUS", tok(tokens, 1).type)
        end)

        it("throws UNEXPECTED_CHAR with the correct error type for an unknown symbol", function()
            local ok, err = pcall(function() scan("@") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_CHAR, err.type)
        end)

        it("reports column 1 for an unknown symbol at the start of input", function()
            local ok, err = pcall(function() scan("@") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(1, err.col)
        end)

        it("includes the bad character in the error message", function()
            local ok, err = pcall(function() scan("@") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.matches("@", err.message)
        end)

        it("reports the correct column when the bad character is not at position 1", function()
            local ok, err = pcall(function() scan("abc @") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNEXPECTED_CHAR, err.type)
            assert.equal(5, err.col)
        end)
    end)

    describe("control-flow keywords", function()
        local cases = {
            { "if", "IF" },
            { "else", "ELSE" },
            { "while", "WHILE" },
            { "loop", "LOOP" },
            { "for", "FOR" },
            { "break", "BREAK" },
            { "true", "TRUE" },
            { "false", "FALSE" },
            { "and", "AND" },
            { "or", "OR" },
            { "not", "NOT" },
        }
        for _, case in ipairs(cases) do
            it("tokenises '" .. case[1] .. "' as " .. case[2], function()
                local tokens = scan(case[1])
                assert.equal(1, #tokens)
                assert.equal(case[2], tok(tokens, 1).type)
                assert.is_nil(tok(tokens, 1).literal)
            end)
        end
    end)

    describe("comparison operators", function()
        local cases = {
            { "==", "EQ" },
            { "!=", "NEQ" },
            { "<", "LESS" },
            { "<=", "LESS_EQUAL" },
            { ">", "GREATER" },
            { ">=", "GREATER_EQUAL" },
        }
        for _, case in ipairs(cases) do
            it("tokenises '" .. case[1] .. "' as " .. case[2], function()
                local tokens = scan(case[1])
                assert.equal(1, #tokens)
                assert.equal(case[2], tok(tokens, 1).type)
            end)
        end

        it("uses maximal munch: '==' is one token, not two ASSIGN", function()
            local tokens = scan("a == b")
            assert.equal(3, #tokens)
            assert.equal("EQ", tok(tokens, 2).type)
        end)

        it("still tokenises a lone '=' as ASSIGN", function()
            local tokens = scan("=")
            assert.equal("ASSIGN", tok(tokens, 1).type)
        end)

        it("still tokenises a lone '<' as LESS", function()
            local tokens = scan("a < b")
            assert.equal("LESS", tok(tokens, 2).type)
        end)
    end)

    describe("compound assignment operators", function()
        local cases = {
            { "+=", "PLUS_ASSIGN" },
            { "-=", "MINUS_ASSIGN" },
            { "*=", "STAR_ASSIGN" },
            { "/=", "SLASH_ASSIGN" },
        }
        for _, case in ipairs(cases) do
            it("tokenises '" .. case[1] .. "' as " .. case[2], function()
                local tokens = scan(case[1])
                assert.equal(1, #tokens)
                assert.equal(case[2], tok(tokens, 1).type)
            end)
        end

        it("tokenises 'i += 1' into 3 tokens", function()
            local tokens = scan("i += 1")
            assert.equal(3, #tokens)
            assert.equal("PLUS_ASSIGN", tok(tokens, 2).type)
        end)
    end)

    describe("arithmetic / concat operators", function()
        local cases = {
            { "/", "DIVIDE" },
            { "%", "MODULO" },
            { "^", "POWER" },
            { "++", "CONCAT" },
        }
        for _, case in ipairs(cases) do
            it("tokenises '" .. case[1] .. "' as " .. case[2], function()
                local tokens = scan(case[1])
                assert.equal(1, #tokens)
                assert.equal(case[2], tok(tokens, 1).type)
            end)
        end

        it("uses maximal munch: '++' is one CONCAT, not two PLUS", function()
            local tokens = scan("a ++ b")
            assert.equal(3, #tokens)
            assert.equal("CONCAT", tok(tokens, 2).type)
        end)

        it("uses maximal munch: '/=' is one SLASH_ASSIGN, not DIVIDE then ASSIGN", function()
            local tokens = scan("i /= 2")
            assert.equal(3, #tokens)
            assert.equal("SLASH_ASSIGN", tok(tokens, 2).type)
        end)

        it("still tokenises a lone '/' as DIVIDE", function()
            local tokens = scan("a / b")
            assert.equal("DIVIDE", tok(tokens, 2).type)
        end)
    end)

    describe("comments", function()
        it("skips a line comment to end of line", function()
            local tokens = scan("a // this is ignored\nb")
            assert.equal(2, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
            assert.equal("IDENTIFIER", tok(tokens, 2).type)
            assert.equal(2, tok(tokens, 2).line)
        end)

        it("skips a line comment at end of input (no trailing newline)", function()
            local tokens = scan("a // trailing")
            assert.equal(1, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
        end)

        it("skips an inline block comment", function()
            local tokens = scan("a /* x */ b")
            assert.equal(2, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 2).type)
        end)

        it("skips a multi-line block comment and tracks line numbers", function()
            local tokens = scan("a /* one\ntwo */ b")
            assert.equal(2, #tokens)
            assert.equal(2, tok(tokens, 2).line)
        end)

        it("does not treat '/' or '/=' as a comment", function()
            assert.equal("DIVIDE", tok(scan("a / b"), 2).type)
            assert.equal("SLASH_ASSIGN", tok(scan("i /= 2"), 2).type)
        end)

        it("throws UNTERMINATED_COMMENT for an unclosed block comment", function()
            local ok, err = pcall(function() scan("a /* never closed") end)
            assert.is_false(ok)
            local err = err --[[@as Error]]
            assert.equal(Error.Type.UNTERMINATED_COMMENT, err.type)
        end)
    end)

    describe("semicolon", function()
        it("tokenises ';' as SEMICOLON", function()
            local tokens = scan(";")
            assert.equal(1, #tokens)
            assert.equal("SEMICOLON", tok(tokens, 1).type)
        end)
    end)

    describe("colon", function()
        it("tokenises ':' as COLON", function()
            local tokens = scan(":")
            assert.equal(1, #tokens)
            assert.equal("COLON", tok(tokens, 1).type)
        end)

        it("tokenises 'x: int' into 3 tokens", function()
            local tokens = scan("x: int")
            assert.equal(3, #tokens)
            assert.equal("IDENTIFIER", tok(tokens, 1).type)
            assert.equal("COLON", tok(tokens, 2).type)
            assert.equal("IDENTIFIER", tok(tokens, 3).type)
        end)
    end)

    describe("dot", function()
        it("tokenises '.' as DOT", function()
            local tokens = scan(".")
            assert.equal(1, #tokens)
            assert.equal("DOT", tok(tokens, 1).type)
        end)

        it("tokenises 'self.x' into SELF DOT IDENTIFIER", function()
            local tokens = scan("self.x")
            assert.equal(3, #tokens)
            assert.equal("SELF", tok(tokens, 1).type)
            assert.equal("DOT", tok(tokens, 2).type)
            assert.equal("IDENTIFIER", tok(tokens, 3).type)
        end)
    end)

    describe("source positions", function()
        it("reports line 1 col 1 for the first token", function()
            local tokens = scan("private")
            assert.equal(1, tok(tokens, 1).line)
            assert.equal(1, tok(tokens, 1).column)
        end)

        it("advances column across a single line", function()
            local tokens = scan("a b")
            assert.equal(1, tok(tokens, 1).column)
            assert.equal(3, tok(tokens, 2).column)
        end)

        it("advances line number after a newline", function()
            local tokens = scan("a\nb")
            assert.equal(1, tok(tokens, 1).line)
            assert.equal(2, tok(tokens, 2).line)
        end)

        it("resets column to 1 after a newline", function()
            local tokens = scan("a\nb")
            assert.equal(1, tok(tokens, 2).column)
        end)
    end)

    describe("compound expressions", function()
        it("tokenises 'private x = 10 + 5' into 6 tokens", function()
            local tokens = scan("private x = 10 + 5")
            assert.equal(6, #tokens)
            assert.equal("PRIVATE", tok(tokens, 1).type)
            assert.equal("IDENTIFIER", tok(tokens, 2).type)
            assert.equal("ASSIGN", tok(tokens, 3).type)
            assert.equal("NUMBER", tok(tokens, 4).type)
            assert.equal("PLUS", tok(tokens, 5).type)
            assert.equal("NUMBER", tok(tokens, 6).type)
        end)

        it("tokenises 'private result = 100' into 4 tokens", function()
            local tokens = scan("private result = 100")
            assert.equal(4, #tokens)
        end)

        it("tokenises 'x = 10' into 3 tokens", function()
            local tokens = scan("x = 10")
            assert.equal(3, #tokens)
        end)

        it("handles leading and trailing whitespace", function()
            local tokens = scan("  private x  ")
            assert.equal(2, #tokens)
        end)

        it("handles multiple newlines between tokens", function()
            local tokens = scan("private\n\nx")
            assert.equal(2, #tokens)
            assert.equal(3, tok(tokens, 2).line)
        end)
    end)
end)
