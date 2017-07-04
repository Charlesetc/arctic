
require 'set'
require_relative './phonebook'
require_relative './files'
require_relative './utils'
require_relative './ast'
require_relative './triage'
require_relative './types'

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
  include Triage
  alias_method :run, :run_triage

  def initialize(file, phonebook: nil)
    @file = file
    @phonebook = phonebook || Phonebook.new
  end

  def before_triage(ast)
    raise "already triaged" if ast.type
  end

  def execute_function(function_type)
    returned_values =
      @phonebook.lookup_function(function_type) do |ast, arguments|
        ast.arguments.each_with_index do |name, i|
          @phonebook.insert(name.data, arguments[i])
        end
        ast.children.each { |x| triage(x) }

        ast.children.last ? ast.children.last.type : UnitType.new
      end
    # TODO: assert these are all equal and return it
    returned_values[0]
  end

  def handle_while(stmt)
    # I'm not sure what to make
    # of a return value from a while
    # statement... it seems
    # like a pretty imperative thing.
    stmt.type = UnitType.new
  end

  def handle_inlay(stmt)
    stmt.type = UnitType.new
  end

  def handle_type_check(check)
    checked = check.children[1]
    annotation = check.children[2]
    handle_type_check_on_checked(checked, checked.type, annotation)
    check.type = checked.type
  end

  def handle_type_check_on_checked(checked, checked_type, annotation)
    if annotation.class == Parens
      annotation = annotation.children[0]
    end

    if annotation.class == Object_literal
      if checked_type.class != ObjectType
        error_ast_type(checked, type: checked_type, expected: "an object, as was asserted")
      end

      annotation.fields.each do |name, value|
        checked_value = checked_type.fields[name]
        handle_type_check_on_checked(checked, checked_value, value)
      end

    elsif annotation.token == :ident
      cls = parse_annotation(annotation)
      if checked_type.class != cls
        error_ast_type(checked, type: checked_type, expected: cls.to_s + ", as was asserted")
      end
    else
      error_ast(annotation, "expected ident or object in type annotation")
    end
  end

  def handle_if(ifstmt)
    c = ifstmt.children

    unless c[1].type.class == BoolType
      error_ast_type(c[1], expected: "a boolean")
    end

    if c[3]
      ifret = c[2].children.last
      elseret = c[3].children.last

      ifrett = ifret ? ifret.type : UnitType.new
      elserett = elseret ? elseret.type : UnitType.new

      # Type comparison!
      unless ifrett == elserett
        error_ast_type(ifret, expected: "#{elserett.inspect}, because if statement branches must have the same return type")
      end
      ifstmt.type = ifrett
    else
      # if statements that don't have else branches
      # will always return unit.
      # Specifically, whatever the last item of their
      # block is, it's not paid attention to.
      ifstmt.type = UnitType.new
    end
  end

  def handle_function_call(parens)
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
        parens.type = return_type if return_type
      end
    end
  end

  def handle_true(token)
    token.type = BoolType.new
  end

  def handle_false(token)
    token.type = BoolType.new
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

  def handle_define(item, toplevel:)
    # ASSERT item.children[1] exists and is ident
    # ASSERT item.children[2] exists
    if toplevel
      @phonebook.insert_toplevel(@file.name, item.children[1].data, item.children[2])
    else
      @phonebook.insert(item.children[1].data, item.children[2])
    end
  end

  def handle_object_literal(object)
    object.type = ObjectType.new(
      object.fields.map {|k,v| [k, v.type]}.to_h
    )
  end

  def handle_dot_access(dot)
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

  def handle_variant(parens)
    name = parens.children[0].data
    argtypes = parens.children.drop(1).map do |child|
      child.type
    end
    location = [parens.start, parens.finish]

    parens.type = VariantType.new(
      name,
      argtypes,
      location
    )
  end

  def handle_block(block)
    name = @phonebook.closure_number
    block.type = FunctionType.new(
      [name],
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
    @phonebook.insert_toplevel(@file.name, item.children[1].data, object)
  end
end

