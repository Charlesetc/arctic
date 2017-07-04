
require_relative './utils'

#
# Types
#

class Type
  def ==(another)
    return false unless another.class == self.class
    return false unless another.instance_variables == instance_variables
    (instance_variables - self.class.dont_check).each do |i|
      if instance_variable_get(i) != another.instance_variable_get(i)
        return false
      end
    end
    true
  end

  def inspect
    File.basename(self.class.to_s, "Type")
  end

  def inspect_for_name
    inspect
  end

  def to_s
    inspect
  end

  def self.dont_check
    []
  end
end

class IntegerType < Type ; end
class FloatType < Type ; end
class StringType < Type ; end
class BoolType < Type ; end
class UnitType < Type ; end

class FunctionType < Type
  attr_reader :names, :arity, :arguments
  def initialize(names, arity, arguments: [])
    # keep a reference to the
    # initial function definition
    # just because functions
    # can be passed around and
    # added arguments to.
    @names = names
    @arity = arity
    @arguments = arguments
  end

  def add_arguments(arguments)
    FunctionType.new(
      @names,
      @arity - arguments.length,
      arguments: @arguments + arguments
    )
  end

  def add_names(names)
    FunctionType.new(
      @names + names,
      @arity,
      arguments: @arguments,
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

  def inspect_for_name
    inner = @fields.map {|k,v| [k, v.inspect_for_name]}.flatten.join("__")
    "o_do__#{inner}__end"
  end
end

class VariantType < Type
  attr_accessor :names, :locations

  def self.dont_check
    [:@locations]
  end

  def self.start(name, argtypes, location)
    names = {name => argtypes}
    locations = {name => location}
    self.new(names, locations)
  end

  def initialize(names, locations)
    @names = names
    @locations = locations
  end

  def inspect
    inner = @names.map do |name, argtypes|
      name + " " + argtypes.map { |x| x.inspect }.join(" ")
    end.join(", ")
    "[^ #{inner} ]"
  end

  def inspect_for_name
    inner = @names.map do |name, argtypes|
      name + "_" + argtypes.map { |x| x.inspect_for_name }.join("_")
    end.join("__")
    "v_do__#{inner}__end"
  end
end

# These two merging functions
# recursively merge variants,
# objects, and other types,
# and throw an error if the
# types are incompatible.

def merge_variants(a, b, reason:, ast_for_error:)
  names = a.names.clone

  b.names.each do |name, types|
    if names[name]
      if names[name].length != types.length
        error_ast_type(
          ast_for_error,
          expected: "#{a.inspect} with #{names[name].length} arguments not #{types.length} for variant #{name}",
          type: b
        )
      end
      names[name] = names[name].map.with_index do |atype, i|
        btype = types[i]
        merge_types(atype,
                    btype,
                    reason:reason,
                    ast_for_error:ast_for_error)
      end
    else
      names[name] = types
    end
  end

  VariantType.new(
    names,
    a.locations.merge(b.locations)
  )
end
def merge_types(a, b, reason:, ast_for_error:)
  error = lambda {
    error_ast_type(
      ast_for_error, expected: "#{a.inspect}, because #{reason}",
      type: b
    )
  }

  error.call if a.class != b.class

  if a.class == FunctionType
    a.add_names(b.names)
  elsif a.class == VariantType
    merge_variants(a, b, reason: reason, ast_for_error: ast_for_error)
  elsif a.class == ObjectType
    error.call if a.fields.keys != b.fields.keys
    ObjectType.new(
      a.fields.map do |name, value|
        [
          name,
           merge_types(value, b.fields[name],
                       reason: reason, ast_for_error: ast_for_error)
        ]
      end.to_h
    )
  else
    a
  end
end
