
require_relative './files'
require_relative './typer'

# tokens = Tokenizer.new(ARGF.read.chomp).tokens
# ast = Grammar.new(tokens).produce_ast
# # ast gets mutated
# Typer.new(ast).run

ast = StdinFile.new.parse
Typer.new(ast).run
puts ast.inspect_types
