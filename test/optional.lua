-- string|number
-- ?number
function printn(s, n)
  n = n or 2
  for i = 1, n do print(tostring(s)) end
end

printn(10)
printn({}, "hello")

