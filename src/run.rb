
require_relative './files'
require_relative './typer'

# tokens = Tokenizer.new(ARGF.read.chomp).tokens
# ast = Grammar.new(tokens).produce_ast
# # ast gets mutated
# Typer.new(ast).run

file = StdinFile.new
Typer.new(file).run
puts file.ast.inspect_types
