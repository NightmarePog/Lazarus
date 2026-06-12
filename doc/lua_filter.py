#!/usr/bin/env python3
"""
Doxygen input filter for Lua source files.

Converts Lua comment and function syntax into C-style equivalents so Doxygen
can extract documentation from EmmyLua-annotated (---/@) source files.

Transformations:
  --- doc text       ->  /// doc text
  -- comment         ->  // comment
  function A:b(x)    ->  void A__b(x);
  function A.b(x)    ->  void A_b(x);
  function b(x)      ->  void b(x);
  local function b() ->  void b();
"""

import sys
import re

for raw in open(sys.argv[1]):
    line = raw.rstrip("\n")

    # Triple-dash doc comment (EmmyLua) -> Doxygen C++ line doc comment
    if re.match(r"^\s*---", line):
        line = re.sub(r"^(\s*)---", r"\1///", line)

    # Regular Lua comment -> C++ comment
    elif re.match(r"^\s*--(?!\[\[)", line):
        line = re.sub(r"^(\s*)--", r"\1//", line)

    # method:  function Table:method(args)
    elif m := re.match(r"^(\s*)(?:local\s+)?function\s+([\w.]+):(\w+)\s*\(([^)]*)\)", line):
        indent, tbl, meth, args = m.groups()
        cname = tbl.replace(".", "_")
        line = f"{indent}void {cname}__{meth}({args});"

    # static:  function Table.method(args)  or  function name(args)
    elif m := re.match(r"^(\s*)(?:local\s+)?function\s+([\w.]+)\s*\(([^)]*)\)", line):
        indent, name, args = m.groups()
        cname = name.replace(".", "_")
        line = f"{indent}void {cname}({args});"

    print(line)
