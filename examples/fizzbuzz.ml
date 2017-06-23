let _integer_times brie_i brie_other = begin
  brie_i * brie_other
end

let brie_fizzbuz = begin
  integer_times(100, fun brie_i ->
    if (integer_modulo(brie_i, 3) = 0)
    then
      brie_print("Fizz")
      ...
  )

end

fizzbuzz ()
