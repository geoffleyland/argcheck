function write(f)       -- file
  f:write("hello\n")
end

write(io.stdout)
write(io.stderr)
local f = io.tmpfile()
write(f)
f:close()
pcall(write, f)
pcall(write, 1)