
# [Brie](/) *[ types ]*

Brie's type system has *structural typing*, also known as row polymorphism.

This means that Brie cares about what an object or value *can do*, not what
it's exact type is.

Brie does not have type signatures, and may look like a dynamic language,
but *all type errors appear at compile time*.

So what can you do in Brie?

```
define square : x [
  x * x
]
square 3
square 5.0
```

This works! Even though `3` is an integer and `5.0` is a float, they
both have a `.*` method. Similarly,

```
let square = <sides = 4, color = "blue">
let triangle = <sides = 3, color = "red">

define print_sides : object [ print object.sides ]

print_sides square  -- prints "4"
print_sides triangle  -- prints "3"


-- Compile time error:
let lobster = <color = "red">
print_sides lobster
```

Furthermore, and this is the cool part,
there is no more runtime cost to calling a method
than there is to calling a function. This works
because Brie only allows homogeneous lists.

```
let a = [ 2 , 2.3 ]   -- this fails
```

In order to get heterogeneous data, one must wrap each item in a polymorphic variant:

```
let a = [
  Point <x = 2, y = 3>,
  Person <name = "bob">,
  Number 3
]
```

Note that `Point`, `Person`, and `Number` are not defined anywhere.
They are polymorphic variants that tell the compiler everything in
a given expression with a given tag has the same type.

## Other languages

Is Brie's system replicated in any other languages?

Yes, several have structural typing, including OCaml, Go, and Scala.

Brie is the only one, however, with type inference and a standard library that takes advantage of
its structural typing.

OCaml comes the closest, as it's also type-inferred and has structural
types in objects. However, OCaml very rarely uses its object system and OCaml
uses dynamic dispatch for method calls.

To learn more about Brie, check out [the book](/book.html)!
