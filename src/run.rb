
require_relative './grammar'
require_relative './typer'

t = Tokenizer.new(ARGF.read.chomp)

g = Grammar.new(t.tokens)

ty = Typer.new(g.produce_ast)

ast = ty.produce_ast

ty.print_types

p ty.produce_ast
