
require_relative './files'
require_relative './typer'
require_relative './phonebook'
require_relative './js_compiler'

# tokens = Tokenizer.new(ARGF.read.chomp).tokens
# ast = Grammar.new(tokens).produce_ast
# # ast gets mutated
# Typer.new(ast).run

file = StdinFile.new
phonebook = Phonebook.new

# Typer.new(file, phonebook: phonebook).run

puts
# puts JsCompiler.new(file, phonebook).compile
puts file.ast.inspect
