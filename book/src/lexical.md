# Lexical Basics

## Comments

```lazarus
// This is a line comment

/* This is a
   block comment */
```

## Identifiers

Identifiers start with a letter or underscore, followed by letters, digits, or underscores. The language enforces casing by convention (see [Getting Started](getting-started.md)).

## Keywords

```
import   extern   enum     interface
fn       private  public   mut
static   self     constructor
return   if       else     while
loop     for      in       break
true     false    and      or      not
```

`match` is a soft keyword — it is parsed as a statement opener only when not used as a function name or variable.

## Literals

### Integers

```lazarus
42
0
-7
```

### Floats

```lazarus
3.14
0.5
```

Any number containing a `.` is a float; without it, an integer.

### Booleans

```lazarus
true
false
```

### Strings

See the [Strings](strings.md) chapter for full coverage of string literals including interpolation and triple-quoted strings.
