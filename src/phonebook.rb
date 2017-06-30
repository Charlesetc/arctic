
class PhoneFunction

  attr_reader :ast, :name, :stack

  def initialize(ast, name, stack:)
    @name = name
    @stack = stack.map { |h| h.clone }
    @ast = ast
    @expanded = {}
  end

  def expand(argument_types)
    unless @expanded[argument_types]
      @expanded[argument_types] = deepcopy(@ast)
    end
  end

  def fetch(argument_types)
    @expanded[argument_types]
  end

end

class Phonebook
  # Something that keeps track of names

  def initialize
    @names = [{}]
    @function_literals = {}
  end

  def enter  #scope
    @names << {}
  end

  def exit
    @names.pop
  end

  def lookup(filename, name)
    @names.reverse.each do |chapter|
      if chapter.include?([filename, name])
        return chapter[[filename, name]]
      end
    end
    nil
  end

  def dump_definitions_for_file(filename)
    # I think it's pretty clear this isn't
    # efficient but it also doesn't happen
    # that often so I'm not worried.
    defs = {}
    @names.each do |chapter|
      chapter.each do |k, v|
        fname, var = k
        if fname == filename
          defs[var] = v
        end
      end
    end
    defs
  end

  def insert(filename, name, ast)
    raise "don't insert untyped asts." if ast.type.nil?
    @names.last[[filename, name]] = ast
  end

  def lookup_function(function_type, method: :expand)
    phone_function = @function_literals[function_type.name]
    raise "every block should have been defined." if phone_function.nil?
    arguments = function_type.arguments
    argument_types = arguments.map { |a| a.type }
    ast = phone_function.send(method, argument_types)

    names = @names
    @names = phone_function.stack
    ret = yield(ast, arguments)
    @names = names
    ret
  end

  def insert_block(name, ast)
      @function_literals[name] = PhoneFunction.new(ast, name, stack: @names)
  end

end
