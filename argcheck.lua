-- Copyright (c) 2012 Incremental IP Limited
-- see LICENSE for license information

local type = type
local getinfo, getlocal = debug.getinfo, debug.getlocal
local floor = math.floor
local rawopen, rawpopen, rawtmpfile = io.open, io.popen, io.tmpfile


-- read source files ---------------------------------------------------------

local source_cache = {}

local function read_source_file(filename)
  local source_file = rawopen(filename, r)
  if not source_file then
    source_cache[filename] = -1
    return -1
  end

  local lines = {}
  local i = 1
  for l in source_file:lines() do
    lines[i] = l
    i = i + 1
  end
  source_file:close()
  
  source_cache[filename] = lines
  return lines
end


local function get_source(filename)
  local source = source_cache[filename] or read_source_file(filename)
  return (source ~= -1 and source) or nil
end


-- parse comment lines -------------------------------------------------------

--- Turn a line like "?|string|number" into a list of constraints
-- @tparam string l the line to parse
local function parse_constraints(l)
  local constraints = {}
  local l2 = l:match("%?|?(.*)")
  if l2 then
    constraints[1] = { description = "nil" }
    l = l2
  end
  while true do
    local c, l2 = l:match("([^|]+)|(.*)")
    if not c then
      if l ~= "" then
        constraints[#constraints+1] = { description = l }
      end
      break
    else
      constraints[#constraints+1] = { description = c }
    end
    l = l2
  end

  if not constraints[1] or
     (constraints[1].description == "nil" and not constraints[2]) then
    return
  end

  return constraints
end


--- parse comments like "-- string [foo]"
local function parse_predef_line(l)
  local constraints, name = l:match("%s*%-%-+%s*(%S*)%s*(%S*)")
  if constraints then
    return parse_constraints(constraints), name:match("([%a_][%w_]*)")
  end
end


--- parse comments like "-- @tparam string [foo]"
local function parse_luadoc_predef_line(l)
  local fname = l:match("%s*%-%-+%s*@function%s+([%a_][%w_]*)")
  local constraints, name = l:match("%s*%-%-+%s*@tparam%s+(%S+)%s+(%S*)")
  if constraints then
    return parse_constraints(constraints), name:match("([%a_][%w_]*)"), fname
  else
    return nil, nil, fname
  end
end


--- parse comments like "foo, -- string:"
local function parse_postdef_line(l)
  local name, rest = l:match("%s*([%a_][%w_]*)%s*[,)]%s*%-%-+%s*(.*)")
  local constraints = rest and (rest:match("^([^:%s]+):") or rest:match("^(%S+)%s*$"))
  if constraints then
    return parse_constraints(constraints), name
  end
end


--- parse function names
local function parse_function_name(l)
  return l:match("function%s+([%a_][%w_]*)%s*%(") or
         l:match("([%a_][%w_]*)%s*=%s*function%s*%(")
end


-- parse function comments ---------------------------------------------------

local function parse_function(filename, linedefined)
  local source = get_source(filename)
  if not source then return nil end
  
  -- walk back from linedefined to the start of the comments
  local start_line = 1
  for i = linedefined - 1, 1, -1 do
    if not source[i]:match("%-%-") then
      start_line = i + 1
      break
    end
  end

  -- are we looking at Luadoc comments?
  local parse_pre, parse_post
  if source[start_line]:match("^%s*%-%-%-") then
    parse_pre, parse_post = parse_luadoc_predef_line, parse_postdef_line
  else
    parse_pre, parse_post = parse_predef_line, parse_postdef_line
  end

  local constraints = {}
  local function_name

  -- Walk forward through the pre-definition comments looking for type
  -- constraints
  for i = start_line, linedefined - 1 do
    local c, name, fname = parse_pre(source[i])
    constraints[name or (#constraints+1)] = c
    function_name = function_name or fname
  end

  -- walk forward from the definition looking for comments like
  -- "a, -- <constraint>", stopping when we see the closing parenthesis for
  -- the function arguments
  local i = linedefined
  while i > 0 do
    local line = source[i]
    if i == linedefined then
      function_name = function_name or parse_function_name(line)
      line = line:match("%((.*)")
    end
    local c, name = parse_post(line)
    if c then constraints[name] = c end
    local before_comment = line:match("(.-)%-%-") or line
    if before_comment:match("%)") then
      break
    end
    i = i + 1
  end

  if not next(constraints) then
    return
  else
    return constraints, function_name
  end
end


-- metatable checkers --------------------------------------------------------

local metatable_checkers =
{
  function(constraint, mt)
    return mt.__type == constraint
  end,
  function(constraint, mt)
    return mt.__typename == constraint
  end,
  function(constraint, mt)
    return mt._type == constraint
  end,
  function(constraint, mt)
    return tostring(mt.__type) == constraint
  end,
  function(constraint, mt)
    return mt.__typeinfo and mt.__typeinfo[constraint]
  end,
  function(constraint, mt, v)
    local __type = mt.__type
    return type(__type) == "function" and __type(v) == constraint
  end,
  function(constraint, mt)
    return _G and _G[constraint] == mt
  end,
  function(constraint, mt)
    return _ENV and _ENV[constraint] == mt
  end,
  function(constraint, mt, v, f)
    local i = 1
    while true do
      local name, value = debug.getupvalue(f, i)
      if not name then break end
      if name == constraint and value == mt then return true end
      i = i + 1
    end
  end
}


local metatable_cache = {}

local function metatable_matcher(metatable_name)
  return function(v, t, mt, func)
    if t == "table" or t == "userdata" then
      mt = mt or getmetatable(v)

      if mt then
        local cached = metatable_cache[metatable_name]
        if cached then
          return mt == cached, mt
        end

        for i = 1, #metatable_checkers do
          if metatable_checkers[i](metatable_name, mt, value, func) then
            metatable_cache[metatable_name] = mt
            return true, mt
          end
        end
      end
    end
  end
end


-- function constraints ------------------------------------------------------

local function_constraints =
{
  integer       = function(v, t) return t == "number" and floor(v) == v end,
  anything      = function(v) return v ~= nil end,
}


-- check a single constraint against a value ---------------------------------

local lua_types =
{
  ["nil"]       = true,
  boolean       = true,
  number        = true,
  string        = true,
  ["function"]  = true, 
  userdata      = true,
  thread        = true,
  table         = true
}

for k in pairs(lua_types) do
  lua_types[k] = function(v, t) return t == k end
end


local function compile_constraint(constraint)
  if lua_types[constraint] then
    return lua_types[constraint]

  elseif function_constraints[constraint] then
    return function_constraints[constraint]

  elseif constraint:match('^".*"$') or constraint:match("^'.*'$") then
    local literal = constraint:sub(2, -2)
    return function(v) return v == literal end

  elseif tonumber(constraint) then
    local literal = tonumber(constraint)
    return function(v) return v == literal end

  elseif constraint:match(".*%.%..*") then
    local low, high = constraint:match("(.*)%.%.(.*)")
    local integer = not low:match("[%.eE]") and not high:match("[%.eE]")
    local low, high = tonumber(low), tonumber(high)
    if not low or not high then
      error("Couldn't make sense of range constraint '"..constraint.."'")
    end

    if integer then
      return function(v, t)
          return t == "number" and v == floor(v) and
                 v >= low and v <= high
        end
    else
      return function(v, t)
          return t == "number" and
                 v >= low and v <= high
        end
    end

  else
    return metatable_matcher(constraint)
  end
end


local function compile_constraints(constraints)
  for i, c in ipairs(constraints) do
    c.func = compile_constraint(c.description)
  end
end


-- Find and compile constraints ----------------------------------------------

local constraints_by_func = {}
local constraints_by_line = {}
local function_names_by_line = {}
local function_names_by_func = {}

local function get_constraints(func)
  local constraints, function_name

  local info = getinfo(func, "S")
  local source = info.source:match("@(.*)")
  if not source then
    constraints = -1
  else
    local key = source..":"..tostring(info.linedefined)
    constraints = constraints_by_line[key]
    if constraints then
      function_name = function_names_by_line[key]
    else
      constraints, function_name = parse_function(source, info.linedefined)
      if constraints then
        for k, v in pairs(constraints) do
          compile_constraints(v)
        end
      end
      constraints = constraints or -1
      constraints_by_line[key] = constraints
      function_names_by_line[key] = function_name
    end
  end

  constraints_by_func[func] = constraints
  function_names_by_func[func] = function_name
  return constraints
end


-- check arguments -----------------------------------------------------------

local warn

local function check_arg(value, constraints, argnum, func)
  local vt = type(value)
  local mt
  local ok
  for i = 1, #constraints do
    local pass, mt2 = constraints[i].func(value, vt, mt, func)
    mt = mt or mt2
    if pass then
      ok = true
      break
    end
  end

  if not ok then
    local ts = constraints[1].description
    for i = 2, #constraints - 1 do
      ts = ts..", "..constraints[i].description
    end
    if constraints[2] then
      ts = ts.." or "..constraints[#constraints].description
    end
    local vs = value == nil and "" or " '"..tostring(value).."'"
    local fname =
      -- getinfo(func, "n") doesn't seem to work
      getinfo(3, "n").name or 
      function_names_by_func[func]
    local message = ("bad argument #%d to '%s' (%s expected, got %s%s)"):
                    format(argnum, fname, ts, type(value), vs)
    if warn then
      io.stderr:write(message, "\n")
    else
      error(message, 4)
    end
  end
end


local function check_args()
  -- quickly see if we've parsed this closure before
  local func = getinfo(2, "f").func
  local constraints = constraints_by_func[func]

  -- otherwise, take a longer route
  if not constraints then
    constraints = get_constraints(func)
  end

  if constraints == -1 then return end

  local i = 1
  while true do
    local name, value = getlocal(2, i)
    if not name then break end
    if constraints[name] then
      check_arg(value, constraints[name], i, func)
    end
    if constraints[i] then
      check_arg(value, constraints[i], i, func)
    end
    i = i + 1
  end
end


-- file handling -------------------------------------------------------------

local readable_files = setmetatable({}, { __mode = "k" })
local writable_files = setmetatable({}, { __mode = "k" })

readable_files[io.stdin] = 1
writable_files[io.stdout] = 1
writable_files[io.stderr] = 1

local read_modes = { r=1, ["r+"]=1, ["w+"]=1, ["a+"]=1 }
local write_modes = { w=1, ["r+"]=1, ["w+"]=1, a=1, ["a+"]=1}


io.open = function(name, mode)
  local file, message = rawopen(name, mode)
  if file then
    mode = (mode or "r"):sub(1, 2):lower()
    readable_files[file] = read_modes[mode]
    writable_files[file] = write_modes[write]
  end
  return file, message
end


io.popen = function(name, mode)
  local file, message = rawpopen(name, mode)
  if file then
    mode = (mode or "r"):sub(1, 2):lower()
    readable_files[file] = read_modes[mode]
    writable_files[file] = write_modes[write]
  end
  return file, message
end


io.tmpfile = function()
  local file, message = rawtmpfile()
  if file then
    writable_files[file] = true
  end
  return file, message
end


function_constraints.file    = function(value) return io.type(value) == "file" end
function_constraints.filein  = function(value) return io.type(value) == "file" and readable_files[value] end
function_constraints.fileout = function(value) return io.type(value) == "file" and writable_files[value] end


-- turn it on ----------------------------------------------------------------

local function configure(what)
  if what == "off" then
    if debug.gethook == check_args then
      debug.sethook()
    end
  else
    warn = what == "warn"
    if debug.gethook() ~= check_args then
      debug.sethook(check_args, "c")
    end
  end
end


------------------------------------------------------------------------------

configure()
return configure


------------------------------------------------------------------------------

