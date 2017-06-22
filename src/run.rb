
require_relative './grammar'
require_relative './typer'

t = Tokenizer.new(ARGF.read.chomp)

g = Grammar.new(t.tokens)

ty = Typer.new(g.produce_ast)

ast = ty.produce_ast

p ty.stringify_types

puts ast.inspect_generics
