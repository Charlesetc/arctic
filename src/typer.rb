
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

class Phonebook
  # Something that keeps track of names

  def initialize
    @names = [{}]
  end

  def enter  #scope
    @names << []
  end

  def exit
    @names.pop
  end

  def lookup(name)
    @names.each do |chapter|
      if chapter.include?(name)
        return chapter[name]
      end
    end
    nil
  end

  def insert(name, ast)
    @names.last[name] = ast
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
        # ASSERT item.children[1] exists and is ident
        # ASSERT item.children[2] exists
        @phonebook.insert(item.children[1].data, item.children[2])
      end
    end

    main_function = @phonebook.lookup('main')

    p main_function

  end

end

