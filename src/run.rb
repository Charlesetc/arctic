
require_relative './grammar'
require_relative './typer'
require_relative './verifier'

t = Tokenizer.new(ARGF.read.chomp)

ast = Grammar.new(t.tokens).produce_ast

# ast also gets mutated
typer = Typer.new(ast)
typetable = typer.unification
# puts typer.stringify_types

verifier = Verifier.new(ast, typetable)
verifier.verify

puts
puts ast.inspect_generics
