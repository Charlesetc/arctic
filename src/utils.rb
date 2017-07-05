require_relative './types'

class String

  def valid_integer?
    true if Integer self rescue false
  end

  def valid_float?
    # this index thing because $ only checks that
    # it's the end of a line, not if it's the end
    # of a string
    self =~ /(^\d+([.])?(\d+)?$)/ and not self.index("\n")
  end

end

def error_ast(ast, reason)
  STDERR.puts "Error #{ast.start}:#{ast.finish}: #{reason}", ast.inspect
  exit(0)
end

def error_ast_type(ast, expected:, type: nil)
  type ||= ast.type
  STDERR.puts "Error: Expected #{expected}, but got #{type.inspect}", ast.inspect
  exit(0)
end

def same_dir_as(dirfile, newfile)
  File.dirname(dirfile) + "/" + newfile
end

def specific_fp(name, arguments)
  unless arguments[0].is_a?(Type)
    arguments = arguments.map { |x| x.type }
  end
  tps = arguments.map { |x| x.inspect_for_name }.join("__")
  "fn_#{name}_#{tps}"
end

def partial_call(x)
  ".partial(#{x.compiled}, \"#{x.type.inspect}\")"
end

def parse_annotation(annotation)
  case annotation.data
  when "string"
    StringType
  when "int"
    IntegerType
  when "function"
    FunctionType
  when "unit"
    UnitType
  when "bool"
    BoolType
  when "float"
    FloatType
  when "function"
    FunctionType
  else
    error_ast(annotation, "not a proper type")
  end
end

def iscapital(c)
  c and c < 'Z' and c > 'A'
end
