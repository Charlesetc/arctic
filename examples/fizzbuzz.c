
int _integer_modulo(int artic_a, int artic_b) {
  return (a % b)
}

void _closure_0(int artic_i) {
  if (_integer_modulo(artic_i, 3) == 0) {
    print("Fizz"); // this string type will end up being more complicated.
  } // else ... etc
}

void *artic_fizzbuzz(void) {
   return _integer_times(100, _closure_0);
}

int main(void) {
  artic_fizzbuzz();

  return 0;
}
