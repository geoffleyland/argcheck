-- Copyright (c) 2009-2011 Incremental IP Limited
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


-- parse function headers ---------------------------------------------------

local function parse_line(l)
  local type_expression, name = l:match("%s*%-%-+%s*@tparam%s+(%S+)%s+(%S*)")
  if not type_expression then
    type_expression = l:match("%s*%-%-+%s*(.*)")
  end
  
  local types = {}
  local next = type_expression:match("%?|?(.*)")
  if next then
    types[1] = "nil"
    type_expression = next
  end
  while true do
    local t, next = type_expression:match("([^|]+)|(.*)")
    if not t then
      if type_expression ~= "" then types[#types+1] = type_expression end
      break
    else
      types[#types+1] = t
    end
    type_expression = next
  end

  if not types[1] or (types[1] == "nil" and not types[2]) then
    return
  end

  return types, name
end


local function parse_function(filename, linedefined)
  local source = get_source(filename)
  if not source then return nil end
  local start_line = nil
  for i = linedefined - 1, 1, -1 do
    if not source[i]:match("%-%-") then
      start_line = i + 1
      break
    end
  end
  local types = {}
  for i = start_line or 1, linedefined - 1 do
    local t, name = parse_line(source[i])
    if name then
      types[name] = t
    else
      types[#types+1] = t
    end
  end
  if not next(types) then
    return
  else
    return types
  end
end


local function_cache = {}

local function get_function_info(filename, linedefined)
  local key = filename..":"..tostring(linedefined)
  local info = function_cache[key]
  if not info then
    info = parse_function(filename, linedefined)
    function_cache[key] = info == nil and -1 or info
  end
  return (info ~= -1 and info) or nil
end


-- check arguments -----------------------------------------------------------

local warn

local function check_arg(value, types, argnum, fname)
  local ok
  for i = 1, #types do
    local t = types[i]
    if type(value) == types[i] then
      ok = true
      break
    end
  end

  if not ok then
    local ts = types[1]
    for i = 2, #types - 1 do
      ts = ts..", "..types[i]
    end
    if types[2] then ts = ts.." or "..types[#types] end
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
  local info = debug.getinfo(2, "Sn")
  local source_file_name = info.source:match("@(.*)")
  if not source_file_name then return end

  local types = get_function_info(source_file_name, info.linedefined)
  if not types then return end

  local i = 1
  while true do
    local name, value = debug.getlocal(2, i)
    if not name then break end
    if types[name] then
      check_arg(value, types[name], i, info.name)
    end
    if types[i] then
      check_arg(value, types[i], i, info.name)
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

