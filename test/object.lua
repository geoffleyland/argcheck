global_class = {}
local upvalue_class = {}
local type_class = { __type = "type" }
local typename_class = { __typename = "typename" }
local typeinfo_class = { __typeinfo = { typeinfo = true } }

local function test_all(
  a, -- global_class
  b, -- upvalue_class
  c, -- type
  d, -- typename
  e) -- typeinfo
  -- we have to use upvalue_class here so it is, in fact, an upvalue
  print(upvalue_class)
end

test_all(
  setmetatable({}, global_class),
  setmetatable({}, upvalue_class),
  setmetatable({}, type_class),
  setmetatable({}, typename_class),
  setmetatable({}, typeinfo_class))

test_all(
  setmetatable({}, global_class),
  setmetatable({}, upvalue_class),
  setmetatable({}, type_class),
  setmetatable({}, typename_class),
  setmetatable({}, typeinfo_class))

test_all(1)    