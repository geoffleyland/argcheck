-- Copyright (c) 2012 Incremental IP Limited
-- see LICENSE for license information


-- read source files ---------------------------------------------------------

local source_cache = {}

local function read_source_file(filename)
  local source_file = io.open(filename, r)
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
    constraints[1] = "nil"
    l = l2
  end
  while true do
    local c, l2 = l:match("([^|]+)|(.*)")
    if not c then
      if l ~= "" then constraints[#constraints+1] = l end
      break
    else
      constraints[#constraints+1] = c
    end
    l = l2
  end

  if not constraints[1] or
     (constraints[1] == "nil" and not constraints[2]) then
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
  local constraints, name = l:match("%s*%-%-+%s*@tparam%s+(%S+)%s+(%S*)")
  if constraints then
    return parse_constraints(constraints), name:match("([%a_][%w_]*)")
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

  -- Walk forward through the pre-definition comments looking for type
  -- constraints
  for i = start_line, linedefined - 1 do
    local c, name = parse_pre(source[i])
    constraints[name or (#constraints+1)] = c
  end

  -- walk forward for the looking for comments like
  -- "a, -- <constraint>", stopping when we see the closing parenthesis for
  -- the function arguments
  local i = linedefined
  while i > 0 do
    local line = source[i]
    if i == linedefined then
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
    return constraints
  end
end


local constraint_cache = {}

local function get_constraints(filename, linedefined)
  local key = filename..":"..tostring(linedefined)
  local constraints = constraint_cache[key]
  if not info then
    constraints = parse_function(filename, linedefined)
    constraint_cache[key] = constraints == nil and -1 or constraints
  end
  return (constraints ~= -1 and constraints) or nil
end


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

local function check_constraint(value, constraint, func)
  if lua_types[constraint] then
    return type(value) == constraint
  elseif type(value) == "table" then
    local mt = getmetatable(value)
    if mt then
      -- try to work out if the constraint name is in any way associated
      -- with the metatable
      if mt.__type == constraint or
         mt.__typename == constraint or
         (mt.__typeinfo and mt.__typeinfo[constraint]) then
        return true
      end
      if _G and _G[constraint] == mt then return true end
      if _ENV and _ENV[constraint] == mt then return true end
      local i = 1
      while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if name == constraint and value == mt then return true end
        i = i + 1
      end
    end
  end
end


-- check arguments -----------------------------------------------------------

local warn

local function check_arg(value, constraints, argnum, fname, func)
  local ok
  for i = 1, #constraints do
    if check_constraint(value, constraints[i], func) then
      ok = true
      break
    end
  end

  if not ok then
    local ts = constraints[1]
    for i = 2, #constraints - 1 do
      ts = ts..", "..constraints[i]
    end
    if constraints[2] then ts = ts.." or "..constraints[#constraints] end
    local message = ("bad argument #%d to '%s' (%s expected, got %s)"):
                    format(argnum, fname, ts, type(value))
    if warn then
      io.stderr:write(message, "\n")
    else
      error(message, 4)
    end
  end
end


local function check_args()
  local info = debug.getinfo(2, "Snf")
  local source_file_name = info.source:match("@(.*)")
  if not source_file_name then return end

  local constraints = get_constraints(source_file_name, info.linedefined)
  if not constraints then return end

  local i = 1
  while true do
    local name, value = debug.getlocal(2, i)
    if not name then break end
    if constraints[name] then
      check_arg(value, constraints[name], i, info.name, info.func)
    end
    if constraints[i] then
      check_arg(value, constraints[i], i, info.name, info.func)
    end
    i = i + 1
  end
end


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

