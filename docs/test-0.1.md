# Lazarus ver test 0.1

## comments
```
// single line
```
```
/*
multi
line
*/
```

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
```
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

## scopes
```
{
    // I am a scope!
    let foo = 5;
}
print(foo); // Error! Foo is not in this Scope
```
## functions
```
let func = () => {
    // function!
}

func()
```

```
let add = (num1: number, num2: number): number => {
    return num1+num2
}
add(5, 10);
add("abcd", 5) // this won't compile!
```

## logic and arithmetic
```
&& - logic and
|| - logic or
== - equals
<= - less or equal
>= - greater or equal
< - less
> - greater
! - not
!= - not equal
++ - increment
-- - decrement
```