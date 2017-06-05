
require_relative './grammar'

t = Tokenizer.new(ARGF.read.chomp)

g = Grammar.new(t.tokens)

p g.ast
