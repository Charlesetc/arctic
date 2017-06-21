
int _integer_modulo(int arctic_a, int arctic_b) {
  return (a % b)
}

void _closure_0(int arctic_i) {
  if (_integer_modulo(arctic_i, 3) == 0) {
    print("Fizz"); // this string type will end up being more complicated.
  } // else ... etc
}

void *arctic_fizzbuzz(void) {
   return _integer_times(100, _closure_0);
}

int main(void) {
  arctic_fizzbuzz();

  return 0;
}
