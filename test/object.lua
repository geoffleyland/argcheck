global_class = {}
local upvalue_class = {}
local type_class = { __type = "type_class" }
local typename_class = { __typename = "typename_class" }
local typeinfo_class = { __typeinfo = { typeinfo_class = true } }

local registry_class = {}
debug.getregistry().registry_class = registry_class

local function test_all(
  a, -- global_class
  b, -- upvalue_class
  c, -- type_class
  d, -- typename_class
  e, -- registry_class
  f) -- typeinfo_class
  -- we have to use upvalue_class here so it is, in fact, an upvalue
  print(upvalue_class)
end

test_all(
  setmetatable({}, global_class),
  setmetatable({}, upvalue_class),
  setmetatable({}, type_class),
  setmetatable({}, typename_class),
  setmetatable({}, registry_class),
  setmetatable({}, typeinfo_class))

test_all(
  setmetatable({}, global_class),
  setmetatable({}, upvalue_class),
  setmetatable({}, type_class),
  setmetatable({}, typename_class),
  setmetatable({}, registry_class),
  setmetatable({}, typeinfo_class))

test_all(1)    