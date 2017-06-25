
-- a macro/ast-operation that composes functions


-- There's often a need to compose functions
-- sometimes because of promises
-- One way is to pass around closures

let_in x 3 [
  x
]


-- the '->' signifies that the rest of the block
-- is actually a new block to the first let_in
let_in x 3 ->
x

-- This works well:

let_in x 3 -> print x
  x + 2

-- ( i.e. whitespace only matters to determine the ending of lines
--   it still will read to the end of the block.)

Lastly,

(let_in x 3 -> x)


-- I guess this is also possible

100.times : x -> x + 2


-- Okay!
-- so basically we made a new syntax for blocks that I also like.

-- : x -> line ; line ; line
-- it's unintuitive because it reads all the lines until the end.
-- but that makes it very powerful.
--
-- and it can be shortened to
-- -> line ; line ; line
-- if there are no arguments
