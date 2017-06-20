
require 'testrocket'

require_relative '../src/grammar'

def ast(input)
  t = Tokenizer.new(input)
  g = Grammar.new(t.tokens)
  g.produce_ast
end

$i = 0
def compare(input, *expected)
  $i += 1
  expected = "root[#{expected.join(", ")}]"
  found = ast(input).inspect
  passed = found == expected

  if not passed and  ENV['debug'] and ($i / 10) == ENV['debug'].to_i
    p expected
    p ast(input).inspect
  end
  passed
end

# Basic Parsing

+-> { compare "foobar", ":ident(foobar)"  }
--> { compare "foobar", ":idont(fuubar)"  }
+-> { compare "1234", ":ident(1234)"  }
compare "foobar", ":ident(foobar)"

# Parentheses

+-> { compare "(())", "(())" }
+-> { compare "hi (there) you", ":ident(hi)", "(:ident(there))", ":ident(you)" }

# Blocks
+-> { compare "[ [ x ] ]", "block[][(block[][(:ident(x))])]" }
+-> { compare "this [ x ]", ":ident(this)", "block[][(:ident(x))]" }
+-> { compare ": [ x ]", "block[][(:ident(x))]" }
+-> { compare ": x [ x ]", "block[:ident(x)][(:ident(x))]" }

# Objects

+-> { compare "<x = y>", "<x = (:ident(y))>" }
+-> { compare "<x= y>", "<x = (:ident(y))>" }
+-> { compare "<x =y>", "<x = (:ident(y))>" }
+-> { compare "<x=y>", "<x = (:ident(y))>" }
+-> { compare "<x = y, y = z>", "<x = (:ident(y)) , y = (:ident(z))>" }
+-> { compare "<x = <y = z>>", "<x = (<y = (:ident(z))>)>" }

# Combinations

+-> { compare "<x = (f a)>", "<x = ((:ident(f) :ident(a)))>" }
+-> { compare ": x [ < y = x > ]", "block[:ident(x)][(<y = (:ident(x))>)]"}
compare "<x = (f a)>", "<x = ((:ident(f) :ident(a)))>"

# Operators

+-> { compare "(2 * 3)", "(:ident(*) (:ident(2)) (:ident(3)))" }
+-> { compare "(2 - 3)", "(:ident(-) (:ident(2)) (:ident(3)))" }
+-> { compare "(2 and 3)", "(:ident(and) (:ident(2)) (:ident(3)))" }
+-> { compare "(1 + 2 - 3)", "(:ident(+) (:ident(1)) (:ident(-) (:ident(2)) (:ident(3))))" }
+-> { compare "(1 - 2 + 3)", "(:ident(-) (:ident(1)) (:ident(+) (:ident(2)) (:ident(3))))" }
+-> { compare "(1 * 2 - 3)", "(:ident(-) (:ident(*) (:ident(1)) (:ident(2))) (:ident(3)))" }
+-> { compare "(3 - 1 * 2)", "(:ident(-) (:ident(3)) (:ident(*) (:ident(1)) (:ident(2))))" }
+-> { compare "(this and that or not)", "(:ident(or) (:ident(and) (:ident(this)) (:ident(that))) (:ident(not)))" }


# Line numbers

+-> {
  a = ast "[ (2 + [ 2 ]) ]"
  a.children[0].start == 3 and
  a.children[0].finish == 12
}

+-> {
  a = ast "[ [2 + [ 2 ]] ]"
  a.children[0].start == 2 and
  a.children[0].finish == 13
}

+-> {
  a = ast "[ : x [ [ 2 ]] ]"
  a.children[0].start == 2 and
  a.children[0].finish == 14
}

+-> {
  a = ast "[ <x = [ 2 ]> ]"
  a.children[0].start == 2 and
  a.children[0].finish == 13
}
