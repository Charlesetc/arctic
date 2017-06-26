
require_relative './grammar'
require_relative './typer'

t = Tokenizer.new(ARGF.read.chomp)

ast = Grammar.new(t.tokens).produce_ast

# ast gets mutated
Typer.new(ast).run

puts ast.inspect_types
