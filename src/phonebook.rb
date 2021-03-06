
require 'set'
require_relative './utils'

class PhoneFunction

  attr_reader :ast, :name, :stack, :expanded

  def initialize(ast, name, stack:)
    @name = name
    @stack = stack.map { |h| h.clone }
    @possible_found = Set.new(stack.map {|h| h.keys}.flatten)
    @found = Set.new
    @ast = ast
    @expanded = {}
  end

  def expand(argument_types)
    first_time = @expanded[argument_types].nil?
    if first_time
      @expanded[argument_types] = deepcopy(@ast)
    end
    [first_time, @expanded[argument_types]]
  end

  def fetch(argument_types)
    [false, @expanded[argument_types]]
  end

  def found(item)
    @found << item
  end

  def all_found
    (@found & @possible_found).to_a
  end

end

class Phonebook
  # Something that keeps track of names

  attr_reader :function_literals

  def initialize
    @names = [{}]
    @toplevel = {}
    @function_literals = {}
    @closure_number = 0
  end

  def enter  #scope
    @names << {}
  end

  def exit
    @names.pop
  end

  def lookup(filename, name)
    @names.reverse.each do |chapter|
      if chapter.include?(name)
        @current_phone_function.found(name) if @current_phone_function
        return chapter[name]
      end
    end
    @toplevel[filename] ||= {}
    @toplevel[filename][name] # will be nil if not there
  end

  def is_toplevel?(fname, name)
    @names.reverse.each do |chapter|
      return false if chapter.include?(name)
    end
    @toplevel[fname][name]
  end

  def dump_definitions_for_file(filename)
    @toplevel[filename]
  end

  def insert(name, ast)
    raise "don't insert untyped asts." if ast.type.nil?
    @names.last[name] = ast
  end

  def insert_toplevel(filename, name, ast)
    @toplevel[filename] ||= {}
    @toplevel[filename][name] = ast
  end

  def lookup_found(name)
    phone_function = @function_literals[name]
    phone_function.all_found
  end

  def lookup_function(function_type, method: :expand)
    rets = []
    function_type.names.each do |name|
      phone_function = @function_literals[name]
      raise "every block should have been defined." if phone_function.nil?
      arguments = function_type.arguments
      argument_types = arguments.map { |a| a.type }
      first_time, ast = phone_function.send(method, argument_types)

      names = @names
      @names = phone_function.stack
      @current_phone_function = phone_function
      rets << yield(ast, arguments, first_time)
      @current_phone_function = nil
      @names = names
    end

    rets
  end

  def insert_block(name, ast)
      @function_literals[name] = PhoneFunction.new(ast, name, stack: @names)
  end

  def closure_number
    @closure_number += 1
  end

  def each_expansion
    @function_literals.each do |k, f|
      f.expanded.each do |argtypes, ast|
        yield ast, argtypes
      end
    end
  end

  def toplevel_extras
    @toplevel.each do |file, defs|
      defs.each do |name, ast|
        yield file, name, ast
      end
    end
  end
end
