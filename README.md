# argcheck - Function argument checking for Lua

## 1. What?

`argcheck` is a Lua module that checks function arguments conform to a
specification.
It's more of a proof of concept at the moment than a fully-developed tool.

`argcheck` is brought to you by
[Incremental](http://www.incremental.co.nz/) (<info@incremental.co.nz>)
and is available under the
[MIT Licence](http://www.opensource.org/licenses/mit-license.php).


## 2. How?

Install with either `sudo make install` (no need to make) or
`luarocks install argcheck` (which doesn't actually work yet, since I haven't
submitted the rock)

Use it with `lua -largcheck file.lua`, or if you want a warning rather than
an error on a failed argument check, `lua -largwarn file.lua`.

Argument specifications are parsed from comments near the function declaration
in the code.

These can be quite simple comments:

    -- string
    -- number
    function printn(s, n)
      for i = 1, n do print(s) end
    end

    printn(10, "hello")

    $ lua -largcheck test/simple.lua 
    lua: test/simple.lua:7: bad argument #1 to 'printn' (string expected, got number '10')

Or LuaDoc-like comments:

    --- prints the string s n times
    -- @tparam number n how many times to print the string
    -- @tparam string s the string to print
    function printn(s, n)
      for i = 1, n do print(s) end
    end

    printn(10, "hello")

    $ lua -largcheck test/ldoc.lua 
    lua: test/ldoc.lua:8: bad argument #1 to 'printn' (string expected, got number '10')

Note that if you name the arguments in LuaDoc comments, they don't have to be
in the right order.

Or comments inline with the function arguments:

    function printn(
      s,  -- string: a string
      n)  -- number: a number
      for i = 1, n do print(s) end
    end

    printn(10, "hello")

    $ lua -largcheck test/simple_arg.lua 
    lua: test/simple_arg.lua:7: bad argument #1 to 'printn' (string expected, got number '10')

In this case, if you want to add a description after the specification,
you'll need to finish the specification with a colon.
This is so you can write:

    function foo(
      a) -- I'd like to comment on this parameter, but not check its type

Without the colon rule, `argcheck` would complain than `a` isn't of type
`I'd`.

You can specify more than one constraint or optional constraints using the
same syntax as [this]
(https://github.com/SierraWireless/luasched/blob/master/c/checks.c):

    -- string|number
    -- ?number
    function printn(s, n)
      n = n or 2
      for i = 1, n do print(tostring(s)) end
    end

    printn(10)
    printn({}, "hello")

    $ lua -largwarn test/optional.lua 
    10
    10
    bad argument #1 to 'printn' (string or number expected, got table 'table ...')
    bad argument #2 to 'printn' (nil or number expected, got string 'hello')

Constraints can be:
  * any of the 8 Lua types (`nil`, `boolean`, `number`, `string`, `function`,
    `userdata`, `thread`, `table`)
  * literal strings in double or single quotes (useful with `|`)
  * literal numbers (again, useful with `|`)
  * number ranges in the form `1..3`. 
    If neither number contains a decimal point or an `e` or `E`
    (as in `10e-3`), it's assumed you also want an integer
  * Names of functions in an internal table you can't change yet.
    So far the only functions in the table are
    + `integer`: the value is a number and an integer
    + `anything`: the value is not nil
  * If none of the above, and the value is table, argcheck will try to match
    the table's metatable to the constraint:
    + if the metatable has a `__type` field that matches the constraint
    + if the metatable has a `__typename` field that matches the constraint
    + if the metatable has a `__typeinfo` field such that
      `mt.__typeinfo[constraint]` is true
    + if there's a `_G[constraint]` or `_ENV[constraint]` is the same as the
      metatable
    + if there's an upvalue whose name matches the constraint and which is the
      same as the metatable (this only works if the correct metatable is
      accessed in the function being checked)


## 3. Requirements

Lua (5.1 or 5.2) or LuaJIT.


## 4. Issues

?


## 5. Wishlist

+ More comprehensive condition checking
+ Pluggable check functions
+ Pluggable object type checkers
+ Compile the checks to a function


## 6. Alternatives

?

