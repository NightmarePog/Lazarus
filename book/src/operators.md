# Operators

## Arithmetic

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `a + b` |
| `-` | Subtraction / unary negation | `a - b`, `-x` |
| `*` | Multiplication | `a * b` |
| `/` | Division | `a / b` |
| `%` | Modulo | `a % b` |
| `^` | Exponentiation | `a ^ b` |

`+` is numeric-only. For string concatenation use `++`.

## Comparison

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater than or equal |

## Logical

| Operator | Description |
|----------|-------------|
| `and` | Logical AND |
| `or` | Logical OR |
| `not` | Logical NOT (prefix) |

## String

| Operator | Description |
|----------|-------------|
| `++` | String concatenation |

## Compound assignment

These desugar to `x = x OP expr` and require `mut`:

| Operator | Desugars to |
|----------|-------------|
| `+=` | `x = x + …` |
| `-=` | `x = x - …` |
| `*=` | `x = x * …` |
| `/=` | `x = x / …` |

## Operator precedence

Higher numbers bind tighter:

| Precedence | Operators |
|-----------|-----------|
| 6 | `^` |
| 5 | `* / %` |
| 4 | `+ - ++` |
| 3 | `== != < <= > >=` |
| 2 | `and` |
| 1 | `or` |

All binary operators are left-associative. Parentheses override precedence.

## Postfix

| Operator | Description |
|----------|-------------|
| `expr.field` | Field / method access |
| `expr[index]` | Index access |
| `expr(args)` | Call |
| `expr?` | Result propagation (unwrap or early-return) |

`.field` and `[index]` on a new line are treated as a new statement, not a chain. They must be on the same line as the preceding expression to chain.
