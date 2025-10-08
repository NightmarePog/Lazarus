# Lazarus 
Lazarus is language compiled into lua code with C/TypeScript like syntax

## features
### basic data types
here, I don't want it complicated and i'll use basic data types lua uses
- string
- number
- boolean 
- nil
- func
- class
### comments
// hello I am a comment!
/*  I am 
    a multiple
    line
    comment!
*/


### code block
```
{
    // some code
}
```
### variable declaration
```
func foo = () => {
    // function body
};
number bee = 5;
```

Lazarus also supports constant variables
const number PI = 3.14;
### basic arithmetic and logic
```
number count = 5+5;
number increment = count++
bool someBool = 5>4 // will be true
```
### functions

func foo = (number x, string y) => {
    // function body
}

Lazarus supports anonymous functions too!
(str x) => {
    //anonymous function!
}

func add = (number x, number y) => {
    return x+y
}

### class
```
class Dog = {
    private string sound;
    constructor = (string sound) => {
        self.sound = sound
    }

    public makeSound = () => {
        print(self.sound);
    }
}

Dog dog = new Dog("Woof!");
dog.makeSound();
// prints Woof!
```

### importing libraries
from here, lazarus is inspired by python
for now, lazarus can only import from other lazarus files
```
// these libraries are non existing
import 'mathLib';
import 'printLib' as printLibrary;
from 'random' import randomVal;

number PI = mathLib.pi;
printLibrary.print(PI, randomVal());
```

### creating libraries
```
export func foo = () => {
    // library function!
}
export const number maxRes = 1920;
```

### while loops
```
while (true) {
    // infinite loop!
}
```

```
number count = 0;
while (count < 10) {
    count++
    // this repeat 10 times!
}
```

### for loop
```
for (number i = 0; i<=10; i++) {
    print(i) // counts to 10
}
```

### if statements
```
if (i < 10) {
    print("i is smaller than 10!")
}
```

### lua scope
```
lua = {
    local string = "Hello world!"
}
```
