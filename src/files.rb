
require_relative './grammar'

class SourceFile

  def initialize(filename)
    @filename = filename
  end

  def read
    File.read(@filename)
  end

  def parse
    tokens = Tokenizer.new(read, file: @filename).tokens
    ast = Grammar.new(tokens).produce_ast
  end

end

class StdinFile < SourceFile
  def initialize
    @filename = "main"
  end
  def read
    ARGF.read
  end
end
