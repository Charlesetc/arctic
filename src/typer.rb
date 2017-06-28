
require 'set'
require_relative './utils'
require_relative './ast'

#
# Types
#

class Type
  def ==(another)
    return false unless another.class == self.class
    return false unless another.instance_variables == instance_variables
    instance_variables.each do |i|
      if instance_variable_get(i) != another.instance_variable_get(i)
        return false
      end
    end
    true
  end

  def inspect
    attrs = instance_variables
      .map {|a| "#{a.to_s[1..a.to_s.length]}=#{instance_variable_get(a)}"}
      .join(", ")
    "#{self.class}(#{attrs})"
  end

  def inspect
    File.basename(self.class.to_s, "Type")
  end

  def to_s
    inspect
  end
end

class IntegerType < Type ; end
class FloatType < Type ; end
class StringType < Type ; end
class UnitType < Type ; end

class FunctionType < Type
  attr_reader :name, :arity, :arguments
  def initialize(name, arity, arguments: [])
    # keep a reference to the
    # initial function definition
    # just because functions
    # can be passed around and
    # added arguments to.
    @name = name
    @arity = arity
    @arguments = arguments
  end

  def add_arguments(arguments)
    FunctionType.new(
      @name,
      @arity - arguments.length,
      arguments: @arguments + arguments
    )
  end
end

class ObjectType < Type
  attr_accessor :fields
  def initialize(fields)
    @fields = fields
  end
  def inspect
    inner = @fields.map do |name, type|
      "#{name} = #{type.inspect}"
    end.join(", ")
    "<#{inner}>"
  end
end

#
# Logic for adding types
#

def deepcopy(ast)
  if ast.is_a? Array
    return ast.map { |x| deepcopy(x) }
  elsif ast.is_a? Hash
    return ast.map { |k, x| [k, deepcopy(x)] }.to_h
  elsif ast.is_a? Symbol or ast.is_a? Fixnum
    return ast
  end
  ast = ast.clone
  ast.instance_variables.each do |var|
    ast.instance_variable_set(
      var,
      deepcopy(ast.instance_variable_get(var))
    )
  end
  ast
end

class Phonebook
  # Something that keeps track of names

  class PhoneFunction

    attr_reader :ast, :name

    def initialize(ast, name)
      @name = name
      @ast = ast
      @expanded = {}
    end

    def expand(argument_types)
      unless @expanded[argument_types]
        deepcopy(@ast)
      end
    end

  end

  PhoneEntry = Struct.new(:ast)

  def initialize
    @names = [{}]
  end

  def enter  #scope
    @names << {}
  end

  def exit
    @names.pop
  end

  def lookup_internal(name)
    @names.reverse.each do |chapter|
      if chapter.include?(name)
        return chapter[name]
      end
    end
    nil
  end

  def lookup(name)
    if (res = lookup_internal(name))
      res.ast
    else
      nil
    end
  end

  def insert(name, ast)
    raise "don't insert untyped asts." if ast.type.nil?
    if ast.type.class == FunctionType
      @names.last[name] = PhoneFunction.new(ast, name)
    else
      @names.last[name] = PhoneEntry.new(ast)
    end
  end

  def lookup_function(function_type)
    phone_function = lookup_internal(function_type.name)
    raise "every function should have been defined." if phone_function.nil?
    arguments = function_type.arguments
    argument_types = arguments.map { |a| a.type }
    ast = phone_function.expand(argument_types)

    if ast
      yield(ast, arguments)
    end # else we've already typed it with these types
  end
end

class Typer

  def initialize(root)
    @root = root
    @phonebook = Phonebook.new
  end

  def run

    # get initial definitions
    @root.children.each do |item|
      raise "this shouldn't happen" unless item.class == Parens
      keyword = item.children[0]

      if keyword.token == :ident and keyword.data == "define"
        handle_define(item)
      end
    end

    main_function = @phonebook.lookup('main')

    error_ast(@root, "no main function") unless main_function


    # execute_function(main_function.type)
    # main_function.children.each { |c| handle_function_call(c) }
    main_function.children.each { |c| triage(c) }
  end

  def handle_function_call(parens)
    raise "already called" if parens.type
    raise "handle_function_call called on not-parens" unless parens.class == Parens
    parens.children.reverse.each { |c| triage(c) }
    first = parens.children[0]
    case parens.children.length
    when 0
      parens.type = UnitType.new
    when 1
      parens.type = first.type
    else
      unless first.type.class == FunctionType
        error_ast_type(first, expected: "a function")
      end
      arguments = parens.children[1...parens.children.length]
      if first.type.arity < arguments.length
        error_ast(first, "Takes #{first.type.arity} arguments but got #{arguments.length}")
      elsif first.type.arity > arguments.length
        parens.type = first.type.add_arguments(arguments)
      else
        execute_function(first.type.add_arguments(arguments))
      end
    end
  end

  def execute_function(function_type)
    @phonebook.enter
    @phonebook.lookup_function(function_type) do |ast, arguments|
      ast.arguments.each_with_index do |name, i|
        @phonebook.insert(name.data, arguments[i])
      end
      ast.children.each { |x| handle_function_call(x) }
    end
    @phonebook.exit
  end

  def triage(ast)
    raise "already triaged" if ast.type
    case
    when ast.class == Token
      handle_token(ast)
    when ast.class == Parens
      keyword = ast.children[0]
      # assuming nonempty parens at the moment
      if keyword and keyword.token == :ident
        case keyword.data
        when "define"
          return handle_define(ast)
        when "if"
          raise "unimplemented"
          return handle_if()
        end
      end
      handle_function_call(ast)
    when ast.class == Object_literal
      handle_object_literal(ast)
    when ast.class == Block
      handle_block(ast)
    when ast.class == Dot_access
      handle_dot_access(ast)
    end
  end

  def handle_token(token)
    case token.token
    when :ident
      if token.data.valid_integer?
        token.type = IntegerType.new
      elsif token.data.valid_float?
        token.type = FloatType.new
      else
        number = @phonebook.lookup(token.data)
        if number.nil?
          error_ast(token, "Undefined reference: #{token.data}")
        end
        token.type = number.type
      end
    when :string
      token.type = StringType.new
    end
  end

  def handle_define(item)
    # ASSERT item.children[1] exists and is ident
    # ASSERT item.children[2] exists
    triage(item.children[2])
    @phonebook.insert(item.children[1].data, item.children[2])
  end

  def handle_object_literal(object)
    object.fields.each { |_, f| handle_function_call f }
    object.type = ObjectType.new(
      object.fields.map {|k,v| [k, v.type]}.to_h
    )
  end

  def handle_dot_access(dot)
    triage(dot.child)
    unless dot.child.type.class == ObjectType
      error_ast_type(dot.child, expected: "object")
    end

    type = dot.child.type.fields[dot.name]
    if type
      dot.type = type
    else
      error_ast_type(dot.child, expected: "object with #{dot.name} field")
    end
  end

  def handle_block(block)
    name = block.hash.to_s
    block.type = FunctionType.new(
      name,
      block.arguments.length
    )
    @phonebook.insert(name, block)
  end
end

