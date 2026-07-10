# Standard Library

The standard library lives in `std/`. Import any module with the `std.` prefix:

```
import std.Sys
import std.Str
import std.List
```

All imports resolve from the project root, never relative to the importing file.

## Objects (static utility modules)

These are `.object.laz` files. All members are static. Call them through the module name.

**`std.Sys`** -- IO and process

```
Sys.print(s)                    // print to stdout
Sys.write(s)                    // write without newline
Sys.read_line()                 // Option<str>
Sys.read_file(path)             // Option<str>
Sys.argv(i)                     // Option<str>
Sys.exit(code)
Sys.exec(cmd)                   // int (exit code)
Sys.capture(cmd)                // Option<str> (stdout)
Sys.file_exists(path)           // bool
Sys.panic(msg)                  // aborts with error()
```

**`std.Str`** -- String operations

```
Str.len(s)                      // Option<int>
Str.sub(s, i, j)               // Option<str>  (1-based, Lua convention)
Str.upper(s)                    // Option<str>
Str.lower(s)                    // Option<str>
Str.find(s, sub)               // Option<int>  (1-based match start)
Str.split(s, sep)              // List<str>
Str.replace(s, from, to)       // str  (first occurrence)
Str.replace_all(s, from, to)   // str
Str.trim(s)                    // str
Str.trim_start(s)              // str
Str.trim_end(s)                // str
Str.pad_left(s, width, fill)   // str
Str.pad_right(s, width, fill)  // str
Str.is_prefix(s, prefix)       // bool
Str.is_suffix(s, suffix)       // bool
Str.chars(s)                   // List<str>  (one per byte)
Str.to_int(s)                  // Option<int>
Str.to_float(s)                // Option<float>
Str.byte(s, i)                 // Option<int>
Str.char(n)                    // Option<str>
Str.rep(s, n)                  // Option<str>
Str.format(fmt, ...)           // dynamic  (Lua string.format)
```

**`std.Num`** -- Math

```
Num.floor(x)                   // Option<int>
Num.ceil(x)                    // Option<int>
Num.abs(x)                     // Option<float>
Num.sqrt(x)                    // float
Num.max(a, b)                  // dynamic
Num.min(a, b)                  // dynamic
Num.clamp(v, lo, hi)           // int
Num.pow(base, exp)             // int
Num.round(x)                   // int
Num.to_int(x)                  // Option<int>
Num.to_float(x)                // Option<float>
Num.to_text(n)                 // Option<str>
```

**`std.Path`** -- File path manipulation

```
Path.join(a, b)
Path.dirname(p)
Path.basename(p)
Path.stem(p)
Path.ext(p)
Path.is_absolute(p)
Path.normalize(p)
```

**`std.Time`** -- Clock

```
Time.now()    // int or float depending on platform
```

**`std.Task`** -- Async utilities (platform-dependent)

```
Task.sleep(n)   // platform(cc) -> os.sleep, platform(roblox) -> task.wait
```

## Classes (instantiable types)

These are `.class.laz` files. Create instances with the class name as a function.

**`std.List`** -- Ordered sequence

```
import std.List

xs = List.new()           // empty list
xs = [1, 2, 3]            // list literal (no import needed for literals)

xs.push(v)
xs.pop()                  // Option<T>
xs.get(i)                 // Option<T>
xs.has(i)                 // bool
xs.len()                  // int
xs.is_empty()             // bool
xs.contains(v)            // bool
xs.first()                // Option<T>
xs.last()                 // Option<T>
xs.delete(i)
xs.copy()                 // List<T>
xs.slice(lo, hi)          // List<T>
xs.join(sep)              // str
xs.map(f)                 // List<U>
xs.filter(f)              // List<T>
xs.fold(init, f)          // A
xs.any(f)                 // bool
xs.all(f)                 // bool
xs.find(f)                // Option<T>
```

**`std.Map`** -- Key-value store

```
import std.Map

m = Map.new()             // empty map
m = ["a": 1, "b": 2]     // map literal

m.get(k)                  // Option<V>
m.has(k)                  // bool
m.len()                   // int
m.is_empty()              // bool
m.delete(k)
m.set(k, v)               // returns the map
m.copy()                  // Map<K,V>
m.keys()                  // List<K>
m.values()                // List<V>
m.map(f)                  // Map<K,U>
m.filter(f)               // Map<K,V>
m.fold(init, f)           // A
m.any(f)                  // bool
m.all(f)                  // bool
m.find(f)                 // Option<V>
```

**`std.Option`** -- Optional values

```
import std.Option

enum Option<T> { Some(T), None }

Option.some(v)            // Option<T>
Option.none()             // Option<T>
Option.is_some(opt)       // bool
Option.is_none(opt)       // bool
Option.unwrap(opt)        // T   (panics on None)
Option.unwrap_or(opt, d)  // T
```

Use `match` or `?` to handle Option values inline without importing.

**`std.Result`** -- Success or failure

```
import std.Result

enum Result<T> { Ok(T), Err(str) }

Result.ok(v)              // Result<T>
Result.err(msg)           // Result<T>
Result.is_ok(res)         // bool
Result.is_err(res)        // bool
Result.unwrap(res)        // T   (panics on Err)
Result.unwrap_or(res, d)  // T
Result.error(res)         // str (the Err message)
```

**`std.File`** -- File handle

```
import std.File

f = File.open(path, mode)   // call through Sys.open
f.write(s)
f.read_line()               // Option<str>
f.read_all()                // Option<str>
f.close()
```

**`std.Json`** -- JSON

```
import std.Json

Json.parse(s)              // dynamic
Json.emit(v)               // str
```
