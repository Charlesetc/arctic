
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

unknown = Unknown.new

assert_aliases(": x [ x ]", {[2,1]=>unknown})
assert_aliases(": x [ define x a\n x ]", {[4,5,6,7]=>unknown})
assert_aliases("[ define x a \n : x [ x ] ]",
               {[8,9,12]=>unknown, [11,10]=>unknown})


