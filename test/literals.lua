function test(
  a, -- "hello"|"goodbye"
  b, -- integer
  c, -- 1|3
  d, -- 1..3
  e) -- 1.0..2.0
  print(a, b, c, d, e)
end

test("hello", 1, 1, 1, 1)
test("goodbye", 2, 3, 2, 2)
test("goodbye", 2, 3, 3, 1.5)

test("bonjour", 1.1, 2, 4, 2.1)