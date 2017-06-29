
require 'set'
require_relative './phonebook'
require_relative './files'
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
  elsif ast.is_a?(Symbol) || ast.is_a?(Fixnum)
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

class Typer

  def initialize(file, phonebook: nil)
    @file = file
    @phonebook = phonebook || Phonebook.new
  end

  def index_file
    # get initial definitions
    @file.ast.children.each do |item|
      raise "this shouldn't happen" unless item.class == Parens
      keyword = item.children[0]

      if keyword.token != :ident
        error_ast(item, "expecting valid top-level identifier")
      end

      # top level items
      case keyword.data
      when "define"
        handle_define(item)
      when "require"
        handle_require(item)
      else
        error_ast(item, "expecting valid top-level identifier")
      end
    end
  end

  def run
    index_file

    main_function = @phonebook.lookup(@file.name, "main")
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
      error_ast_type(first, expected: "a Function") unless first.type.class == FunctionType
      arguments = parens.children[1...parens.children.length]

      # If greater
      if first.type.arity > arguments.length
        parens.type = first.type.add_arguments(arguments)
      else
        # If less than
        if first.type.arity < arguments.length
          if arguments.length == 1 and
             first.type.arity == 0 and
             arguments[0].type.class == UnitType
            arguments = [] # and continue on to the execute function
          else
            error_ast(first, "Takes #{first.type.arity} arguments but got #{arguments.length}")
          end
        end

        # if equal:
        return_type = execute_function(first.type.add_arguments(arguments))
        parens.type = return_type
      end
    end
  end

  def execute_function(function_type)
    @phonebook.enter
    return_type = @phonebook.lookup_function(function_type) do |ast, arguments|
      ast.arguments.each_with_index do |name, i|
        @phonebook.insert(@file.name, name.data, arguments[i])
      end
      ast.children.each { |x| handle_function_call(x) }
    end
    @phonebook.exit
    return_type
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
        number = @phonebook.lookup(@file.name, token.data)
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
    @phonebook.insert(@file.name, item.children[1].data, item.children[2])
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
    @phonebook.insert_block(name, block)
  end

  def handle_require(item)
    # this function parses a file,
    # and then makes a new typer with the
    # same phonebook that goes and fills in
    # the initial top level definitions it
    # encounters.
    #
    # Finally, we make a new object with
    # the name required and define it
    # for this module. This object
    # has references to each of the
    # definitions in the file we parsed.

    # support directories in the future
    filename = item.children[1].data + ".brie"
    filename = same_dir_as(@file.name, filename)

    filetyper = Typer.new(SourceFile.new(filename), phonebook: @phonebook)
    filetyper.index_file

    defs = @phonebook.dump_definitions_for_file(filename)
    error_ast(item, "Can't require files with no definitions") if defs.empty?

    defs = defs.map { |k, v| [k, [v]] }.to_h
    object = Object_literal.new(defs)
    object.type = ObjectType.new(
      object.fields.map do |k,v|
        # they are all parens
        # with one value.
        v.type = v.children[0].type
        [k, v.type]
      end.to_h
    )

    # define it locally
    #
    @phonebook.insert(@file.name, item.children[1].data, object)
  end
end

