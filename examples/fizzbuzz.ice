
-- fizzbuzz.ice

define fizzbuzz [

  100.times : i [
    if i % 3 = 0 [
      print "Fizz"
    ] else if i % 5 = 0  [
      print "Buzz"
    ] else if i % 15 = 0 [
      print "Fizzbuzz"
    ] else [
      print i
    ]
  ]

]

define main [
  fizzbuzz ()
]
