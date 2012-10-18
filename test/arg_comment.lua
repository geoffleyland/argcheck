--- concat 3 things
function concat_print(a, -- string
  b, -- number: any number you like (with parentheses)
  c) -- ?string|number: it can be either on nil!
  print(a..tostring(b)..tostring(c))
end

concat_print("hello", 10, 2)
concat_print("hello", 10, "hello")
concat_print("hello", 10)
concat_print(10, "hello", {})

