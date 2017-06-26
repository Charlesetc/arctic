
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
end

class IntegerType < Type ; end

class StringType < Type ; end

class FunctionType < Type
  attr_accessor :takes, :returns
  def initialize(takes:, returns:)
    @takes = takes
    @returns = returns
  end
end

class ObjectType < Type
  attr_accessor :fields
  def initialize(fields)
    @fields = fields
  end
end

#
# Logic for adding types
#

class Typer

  def initialize(root)
    @root = root
  end

  def run

    p @root


  end

end

