# AST

## __index


```lua
AST
```

## body


```lua
Stmt[]
```

## new


```lua
function AST.new(body: Stmt[])
  -> AST
```

## type


```lua
"Program"
```


---

# BinaryExpr

## left


```lua
Expr
```

## op


```lua
string
```

## right


```lua
Expr
```

## type


```lua
"BinaryExpr"
```


---

# Expr

## type


```lua
string
```


---

# IdentifierExpr

## name


```lua
string
```

## type


```lua
"IdentifierExpr"
```


---

# Lexer

## __index


```lua
Lexer
```

## _advance


```lua
(method) Lexer:_advance()
```

## _next_token


```lua
(method) Lexer:_next_token()
  -> Token?
```

## _read_identifier


```lua
(method) Lexer:_read_identifier()
  -> Token
```

## _read_number


```lua
(method) Lexer:_read_number()
  -> Token
```

## _read_symbol


```lua
(method) Lexer:_read_symbol()
  -> Token
```

## col


```lua
integer
```

## current


```lua
string
```

## line


```lua
integer
```

## new


```lua
function Lexer.new(source: string)
  -> Lexer
```

## pos


```lua
integer
```

## scan


```lua
(method) Lexer:scan()
  -> Token[]
```

## source


```lua
string
```


---

# LiteralExpr

## type


```lua
"LiteralExpr"
```

## value


```lua
any
```


---

# LuaLS


---

# Parser

## __index


```lua
Parser
```

## _advance


```lua
(method) Parser:_advance()
  -> Token
```

## _binary


```lua
fun(self: Parser):Expr
```

## _check


```lua
(method) Parser:_check(type: string)
  -> boolean
```

## _consume


```lua
(method) Parser:_consume(type: string, message: string)
  -> Token
```

## _current


```lua
(method) Parser:_current()
  -> Token?
```

## _expression


```lua
fun(self: Parser):Expr
```

## _is_eof


```lua
(method) Parser:_is_eof()
  -> boolean
```

## _match


```lua
(method) Parser:_match(...string)
  -> boolean
```

## _peek


```lua
(method) Parser:_peek(offset?: integer)
  -> Token?
```

## _previous


```lua
(method) Parser:_previous()
  -> Token?
```

## _primary


```lua
fun(self: Parser):Expr
```

## _statement


```lua
fun(self: Parser):Stmt
```

## new


```lua
function Parser.new(token_table: Token[])
  -> Parser
```

## parse


```lua
(method) Parser:parse()
  -> AST
```

## pos


```lua
integer
```

## token_table


```lua
Token[]
```


---

# PendingToken

## col


```lua
integer
```

## line


```lua
integer
```

## literal


```lua
any
```

## type


```lua
"ASSIGN"|"IDENTIFIER"|"LET"|"MINUS"|"NUMBER"...(+2)
```

## value


```lua
string
```


---

# Stmt

## type


```lua
string
```


---

# Token

## __index


```lua
Token
```

## __tostring


```lua
(method) Token:__tostring()
  -> string
```

## column


```lua
integer
```

## line


```lua
integer
```

## literal


```lua
boolean|string|number|nil
```

 Define the allowed types for a literal

## new


```lua
function Token.new(type: "ASSIGN"|"IDENTIFIER"|"LET"|"MINUS"|"NUMBER"...(+2), value: string, line: integer, column: integer, literal?: boolean|string|number)
  -> Token
```

```lua
type:
    | "LET"
    | "ASSIGN"
    | "PLUS"
    | "MINUS"
    | "IDENTIFIER"
    | "NUMBER"
    | "SYMBOL"
```

## type


```lua
"ASSIGN"|"IDENTIFIER"|"LET"|"MINUS"|"NUMBER"...(+2)
```

## value


```lua
string
```


---

# TokenBuilder

## identifier


```lua
function TokenBuilder.identifier(type: "ASSIGN"|"IDENTIFIER"|"LET"|"MINUS"|"NUMBER"...(+2), value: string, line: integer, col: integer)
  -> Token
```

```lua
type:
    | "LET"
    | "ASSIGN"
    | "PLUS"
    | "MINUS"
    | "IDENTIFIER"
    | "NUMBER"
    | "SYMBOL"
```

## make


```lua
function TokenBuilder.make(type: "ASSIGN"|"IDENTIFIER"|"LET"|"MINUS"|"NUMBER"...(+2), value: string)
  -> PendingToken
```

```lua
type:
    | "LET"
    | "ASSIGN"
    | "PLUS"
    | "MINUS"
    | "IDENTIFIER"
    | "NUMBER"
    | "SYMBOL"
```

## number


```lua
function TokenBuilder.number(value: string, line: integer, col: integer)
  -> Token
```

## with_position


```lua
function TokenBuilder.with_position(token: PendingToken, line: integer, col: integer)
  -> Token
```


---

# TokenLiteral

 Define the allowed types for a literal


---

# TokenType


---

# VariableDecl

## new


```lua
function VariableDecl.new(name: any, value: any)
  -> table
```

## type


```lua
string
```


---

# package.path


```lua
string
```