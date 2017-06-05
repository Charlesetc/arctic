
require 'testrocket'

require_relative '../src/grammar'

$i = 0
def compare(input, *expected)
  $i += 1
  t = Tokenizer.new(input)
  g = Grammar.new(t.tokens)
  expected = "root[#{expected.join(", ")}]"
  found = g.ast.inspect
  passed = found == expected

  if not passed and  ENV['debug'] and ($i / 10) == ENV['debug'].to_i
    p expected
    p g.ast.inspect
  end
  passed
end

# Basic Parsing

+-> { compare "foobar", ":ident(foobar)"  }
--> { compare "foobar", ":idont(fuubar)"  }
+-> { compare "1234", ":ident(1234)"  }

# Parentheses

+-> { compare "(())", "parens[parens[]]" }
+-> { compare "hi (there) you", ":ident(hi)", "parens[:ident(there)]", ":ident(you)" } 

# Blocks
+-> { compare "[ [ x ] ]", "block[][parens[block[][parens[:ident(x)]]]]" }
+-> { compare "this [ x ]", ":ident(this)", "block[][parens[:ident(x)]]" }
+-> { compare ": [ x ]", "block[][parens[:ident(x)]]" }
+-> { compare ": x [ x ]", "block[:ident(x)][parens[:ident(x)]]" }

