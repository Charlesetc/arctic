
require_relative './grammar'
require_relative './typer'

class SourceFile
  attr_reader :ast, :name

  def initialize(name)
    @name = name
    parse
  end

  def read
    File.read(@name)
  end

  def parse
    tokens = Tokenizer.new(read, file: @name).tokens
    @ast = Grammar.new(tokens).produce_ast
  end

end

class StdinFile < SourceFile
  def initialize
    @name = "main"
    parse
  end
  def read
    ARGF.read
  end
end
