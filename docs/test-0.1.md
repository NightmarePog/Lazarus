# Lazarus ver tes 0.1

## comments
```
// single line
```
```
/*
multi
line
*/

## variables and their functions
- able to set if it's mutable
- able to give it a type or make it dynamic
- able to set global vars
examples:
```
// non mutable inicilization
let var: number; 
```
```
// non mutable definition
let var: number = 5;
// or
let var = number
// important notice: compiler can assign data type later
```
```
// here is a mutable variable
let mut var = 5;
var = 8; // I can change variable value without any problem

### union types
- union type is a type where you can assign multiple types to single variable
```
let mut foo: string | number = 5;
foo = "hello world!";
```
### nullable types
```
let input: undefined | string;
input = input_func();
// input_func returns undefined and string
// so you need to check if it's defined
if (type(input) != undefined) {
    // here, we are that that input is string
}
```

