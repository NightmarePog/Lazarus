# pipeline
```
lexer -> parser -> schematic analyzer -> arithmetic analyzer -> intermediate Representation -> lua code
```
## Lexer
- deletes comments
- returns code as tokens
example:
```
extern let print = (...);

let main = () => {
    // I am a comment!
   print("hello world!");
   return 0;
}
```
after lexer:
```
TYPE: identifier, VALUE: extern
TYPE: identifier, VALUE: let
TYPE: identifier, VALUE: print
TYPE: laz_assign_operator_single, VALUE: =
TYPE: laz_paren_open, VALUE: (
TYPE: variables_undefined_count, VALUE: ...
TYPE: laz_paren_close, VALUE: )
TYPE: laz_expression_end, VALUE: ;
TYPE: identifier, VALUE: let
TYPE: identifier, VALUE: main
TYPE: laz_assign_operator_single, VALUE: =
TYPE: laz_paren_open, VALUE: (
TYPE: laz_paren_close, VALUE: )
TYPE: operator_function, VALUE: =>
TYPE: laz_brace_open, VALUE: {
TYPE: identifier, VALUE: print
TYPE: laz_paren_open, VALUE: (
TYPE: string, VALUE: hello world!
TYPE: laz_paren_close, VALUE: )
TYPE: laz_expression_end, VALUE: ;
TYPE: returns_keyword, VALUE: return
TYPE: number, VALUE: 0
TYPE: laz_expression_end, VALUE: ;
TYPE: laz_brace_close, VALUE: }
```
## Parser
- parse Lexer output into trees that are much easier to work with
- NOT IMPLEMENTED YET

## Schematic analyzer 
- checks if types are right
- checks if identifiers even exists
- checks mutability

## Arithmetic Analyzer
- sets arithmetic into correct order
example: 
```
x = 5*5+5 -> x_temp1 = 5*5; x = x_temp1+5
```
not sure if i'll add: arithmetic optimalization:
```
5*5 - will always be 25
so why not just putting 25 instead of 5*5 there
```

## intermediate Representation
- represent code in simplest terms
- easily parseable

## lua compilation
- compiles code into final version