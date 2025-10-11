start program:
## input
```
extern let print = (...);

let main = () => {
   print("hello world!");
   return 0;
}
```

## lexer output

```
TYPE: identifier, VALUE: extern
TYPE: laz_variable_initilization, VALUE: let
TYPE: identifier, VALUE: print
TYPE: laz_assign_operator_single, VALUE: =
TYPE: laz_paren_open, VALUE: (
TYPE: laz_undefined_count_parameters, VALUE: ...
TYPE: laz_paren_close, VALUE: )
TYPE: laz_expression_end, VALUE: ;
TYPE: laz_variable_initilization, VALUE: let
TYPE: identifier, VALUE: main
TYPE: laz_assign_operator_single, VALUE: =
TYPE: laz_paren_open, VALUE: (
TYPE: laz_paren_close, VALUE: )
TYPE: laz_func_arrow_operator_compound, VALUE: =>
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

## AST output
```