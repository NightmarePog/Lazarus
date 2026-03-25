# LANGUAGE SPEC 1.0

## 1. Basic Rules
- Everything is a class
- One file = one class
- No global functions or variables
- Program starts at Main.main()

---

## 2. Import

import math.Math
import utils.Strings

---

## 3. Data Types

number
string
bool
nil

---

## 4. Collections

# Array
let list = [1, 2, 3]

# Map / Dictionary
let obj = { name: "John", age: 25 }

---

## 5. Operators

# Math
+  -  *  /
++  --

# Logic
and
or
!

# Comparison
==  !=
>   <
>=  <=

---

## 6. Variables

let x = 10
const y = 5

let a: number = 10
const name: string = "John"

---

## 7. Class

class Player extends Entity {
}

---

## 8. Constructor

func init(x, y) {
    self.x = x
    self.y = y
}

---

## 9. Methods

# Instance
func move(x, y) {
    self.x += x
}

# Static
static func add(a, b) {
    return a + b
}

---

## 10. Access Modifiers

private func foo() { }
public func bar() { }

---

## 11. Loops

# For loop
for i = 1, 10 {
}

# Foreach
for item in list {
}

for i, item in list {
}

# While loop
while (true) {
}

# Control
break
continue

---

## 12. Control Flow

if (x > 10) {
} else if (x > 5) {
} else {
}

---

## 13. Return

return
return x

---

## 14. Built-in Class

class Global {
    static func print(x) { }
}

# Usage
print("hello")

---

## 15. Entry Point

class Main {
    static func main() {
        print("Hello world")
    }
}

---

## 16. Creating Objects

let p = Player(10, 20)

---

## 17. self

self.x = 10

---

## 18. Comments

// single-line comment

/* block comment */

---

## 19. Type System

# Basic types
number
string
bool
nil

# Nullable
let x: number? = nil

---

## 20. Function Types

func add(a: number, b: number): number {
    return a + b
}

func log(x: string): nil {
    print(x)
}

---

## 21. Class Types

class Player {
    let x: number
    let y: number

    func init(x: number, y: number) {
        self.x = x
        self.y = y
    }
}

---

## 22. Typed Collections

let list: [number] = [1, 2, 3]

let names: [string] = ["a", "b"]

let map: {string: number} = {
    "a": 1,
    "b": 2
}

---

## 23. Type Rules

- Types are static (checked at compile-time)
- Types can be inferred (let x = 10)
- nil is only compatible with nullable types
- Type cannot change after assignment
- const cannot be reassigned

---

## 24. Casting

let x: number = 10
let y: string = x as string

---

## 25. Inline Lua

# Basic usage
lua {
    print("hello from lua")
}

---

## 26. Lua inside Method

func test() {
    lua {
        print("inside lua block")
    }
}

---

## 27. Access self in Lua

func move() {
    lua {
        self.x = self.x + 1
    }
}

---

## 28. Returning from Lua

func getNumber(): number {
    return lua {
        return 42
    }
}

---

## 29. Lua with Variables

func test() {
    let x: number = 10

    lua {
        print(x)
    }
}

---

## 30. Lua Limitations

- Lua block ignores type checking
- Lua code is inserted directly into output
- Lua has access to local variables and self
- Lua can modify program state
- Should be used carefully (unsafe)
