
class String

  def valid_integer?
    true if Integer self rescue false
  end

  def valid_float?
    true if Float self rescue false
  end

end

def error_ast(ast, reason)
  STDERR.puts "Error: #{reason}", ast
  exit(0)
end

def error_ast_type(ast, type)
  STDERR.puts "Error: Expected #{type}, but got #{ast.type.inspect}", ast
  exit(0)
end
