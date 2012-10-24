require("argcheck")

function test_file(f)       -- file
  print(f)
end

function test_filein(f)     -- filein
  print(f)
end

function test_fileout(f)    -- fileout
  print(f)
end

local function broke(f, ...)
  local ok, message = pcall(f, ...)
  assert(not ok)
  io.stderr:write(message, "\n")
end


test_file(io.stdin)
test_file(io.stdout)
test_file(io.stderr)

test_filein(io.stdin)
broke(test_filein, io.stdout)
broke(test_filein, io.stderr)

broke(test_fileout, io.stdin)
test_fileout(io.stdout)
test_fileout(io.stderr)

local f = io.tmpfile()
test_file(f)
broke(test_filein, f)
test_fileout(f)

f:close()
broke(test_file, f)
broke(test_filein, f)
broke(test_fileout, f)


broke(test_file, 1)
broke(test_filein, 1)
broke(test_fileout, 1)