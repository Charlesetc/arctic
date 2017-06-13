
require_relative './grammar'
require_relative './typer'

t = Tokenizer.new(ARGF.read.chomp)

g = Grammar.new(t.tokens)

ty = Typer.new(g.produce_ast)

p ty.produce_ast
