# Language Structure

Main.laz
```laz
public func foo(): void {
  print("Hello World!")
}

func Main(): void {
  foo()
```
so this is simple language structure. as you can see the class is that file, with that we have encapsulation. But what about polymorphism and encapsulation?

```laz
extends Foo

public func foo() {
  print("Hi!")
  let boo: Boo = new Boo()
}
