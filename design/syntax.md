

# Brie *[ syntax ]*

Brie's syntax starts with the syntax of a basic ml language like Haskell.
```
            -- Comments
2 + 2 / 3   -- Operators
print "hi"  -- Function calls
let x = 2   -- Bindings
```

Then we add the lambda syntax `: [ ]`, which is used for
blocks, functions, classes, etc.


```
[1,2,3].map : x [ x * x ]

define hello_world [
  "Screw you, world!"
]
```

Objects have literals; you don't need to define a class.

```
let mysheep = <fluffy = true, name = "Herbert">
print mysheep.name
```

But you definitely can.

```
class sheep [
  field fluffy = true
  field name
  method print_name = print name
]
let mysheep = sheep <name = "Herbert">

mysheep.fluffy    --> true
mysheep.print_name
```

And that is the syntax! Learn more about Brie by looking at its [*type system*](./types.html).
