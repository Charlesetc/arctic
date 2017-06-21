
require 'pry'
require 'testrocket'

require_relative '../src/typer'
require_relative '../src/grammar'


# Aliases

def assert_aliases(text, aliases)

  t = Tokenizer.new(text)
  g = Grammar.new(t.tokens)
  ty = Typer.new(g.produce_ast)
  ty.produce_ast

  pass = aliases.inspect == ty.stringify_types

  if not pass
    puts "found:    #{aliases.inspect}"
    puts "expected: #{ty.stringify_types.inspect}"
  end

  +-> { pass }
end

assert_aliases(": x [ x ]", {[2,1]=>Unknown})
assert_aliases(": x [ define x 2\n x ]", {[4,5,6,7]=>Unknown})
assert_aliases("[ define x 2 \n : x [ x ] ]",
               {[8,9,12]=>Unknown, [11,10]=>Unknown})


