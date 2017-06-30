
require_relative './files'
require_relative './typer'
require_relative './phonebook'

# tokens = Tokenizer.new(ARGF.read.chomp).tokens
# ast = Grammar.new(tokens).produce_ast
# # ast gets mutated
# Typer.new(ast).run

file = StdinFile.new
phonebook = Phonebook.new

Typer.new(file, phonebook: phonebook).run
puts file.ast.inspect_types
