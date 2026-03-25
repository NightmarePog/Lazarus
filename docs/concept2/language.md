# LANGUAGE SPEC 1.0

## 1. Základní pravidla
- vše je class
- jeden soubor = jedna class
- žádné globální funkce ani proměnné
- program začíná v Main.main()

---

## 2. Import

import math.Math
import utils.Strings

---

## 3. Datové typy

number
string
bool
nil

---

## 4. Kolekce

# Array
let list = [1, 2, 3]

# Map
let obj = { name: "John", age: 25 }

---

## 5. Operátory

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

## 6. Proměnné

let x = 10
const y = 5

---

## 7. Class

class Player extends Entity {
}

---

## 8. Konstruktor

func init(x, y) {
    self.x = x
    self.y = y
}

---

## 9. Metody

# Instance
func move(x, y) {
    self.x += x
}

# Static
static func add(a, b) {
    return a + b
}

---

## 10. Access modifiers

private func foo() { }
public func bar() { }

---

## 11. Loops

# For
for i = 1, 10 {
}

# Foreach
for item in list {
}

for i, item in list {
}

# While
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

## 14. Built-in

class Global {
    static func print(x) { }
}

# usage
print("hello")

---

## 15. Entry point

class Main {
    static func main() {
        print("Hello world")
    }
}

---

## 16. Vytváření objektů

let p = Player(10, 20)

---

## 17. self

self.x = 10

---

## 18. Komentáře

// line comment

/* block comment */
