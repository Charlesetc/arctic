
int _integer_modulo(int brie_a, int brie_b) {
  return (a % b)
}

void _closure_0(int brie_i) {
  if (_integer_modulo(brie_i, 3) == 0) {
    print("Fizz"); // this string type will end up being more complicated.
  } // else ... etc
}

void *brie_fizzbuzz(void) {
   return _integer_times(100, _closure_0);
}

int main(void) {
  brie_fizzbuzz();

  return 0;
}
