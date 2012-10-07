# argcheck - argument checking for Lua

## 1. What?

argcheck is a Lua module that checks function arguments conform to a
specification.
It's more of a proof of concept at the moment than a fully-developed tool.

argcheck is brought to you by [Incremental](http://www.incremental.co.nz/) (<info@incremental.co.nz>)
and is available under the
[MIT Licence](http://www.opensource.org/licenses/mit-license.php).


## 2. How?

`lua -largcheck file.lua`, or if you want a warning rather than an error
on a failed argument check, `lua -largwarn file.lua`.

Argument specifications are parsed from comments near the function declaration
in the code.

These can be very simple comments:

    -- string
    -- number
    function printn(s, n)
      for i = 1, n do print(s) end
    end

    printn(10, "hello")

    $ lua -largcheck test/simple.lua 
    lua: test/simple.lua:7: bad argument #1 to 'printn' (string expected, got number)

Or LuaDoc-like comments:

    --- prints the string s n times
    -- @tparam number n how many times to print the string
    -- @tparam string s the string to print
    function printn(s, n)
      for i = 1, n do print(s) end
    end

    printn(10, "hello")

    $ lua -largcheck test/ldoc.lua 
    lua: test/ldoc.lua:8: bad argument #1 to 'printn' (string expected, got number)

Note that if you name the arguments in LuaDoc comments, they don't have to be
in the right order.

You can specify more than one type, or optional arguments using the same
syntax as [this]
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
    bad argument #1 to 'printn' (string or number expected, got table)
    bad argument #2 to 'printn' (nil or number expected, got string)


## 3. Requirements

Lua (5.1 or 5.2) or LuaJIT.


## 4. Issues

+ Only handles the simplest form of ldoc comments
+ Doesn't handle metatable types and checker functions like checks.c


## 5. Wishlist

+ Range and condition checking?


## 6. Alternatives

?

