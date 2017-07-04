
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

class VariantType < Type
  attr_accessor :names, :locations

  def initialize(name, argtypes, location)
    @names = {name => argtypes}
    @locations = {name => location}
  end

  def merge(other, reason:, ast_for_error:)
    @names.each do |k, v|
      if other.names[k] and other.names[k] != v
        error_ast(ast_for_error,
                  "merging variables: " +
                  "found for name #{k} type #{v} " +
                  "at #{@locations[k]}" +
                  "but also found type #{other.names[k]} " +
                  "at #{other.locations[k]}"
                 )
      end
    end

    newone = self.clone
    newone.names = names.merge(other.names)
    # not sure if this is needed:
    newone.locations = locations.clone
    newone
  end
  def inspect
    inner = @names.map do |name, argtypes|
      name + " " + argtypes.map { |x| x.inspect }.join(" ")
    end.join(", ")
    "[^ #{inner} ]"
  end
end
