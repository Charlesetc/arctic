
require 'set'
require_relative './ast'

#
# Types
#

Generic = Struct.new(:id, :start, :finish)

class Type ; end # this type is not meant to be instantiated

class Unknown < Type  ; end

class Literal < Type ; end

class Function < Type ; end

class Open_object < Type ; end

$generic_counter = 0

def new_generic(start, finish)
  Generic.new(i, start, finish)
  $generic_counter += 1
end


#
# Ast
#

# reopening the class to add
# type-specific features 
class Ast
  
  # lazily make the types!
  def type
    if @type.nil?
      @type = new_generic(@start, @finish)
    else
      @type
    end
  end

end

class Typetable

  def initialize

    # map from sets of Generics to their type.
    #
    # this is the source of truth.
    @type_mapping = {}
  end

  def get_type_of_generic(generic)
    @type_mapping.each do |k, v|
      if k.include? generic
        return v
      end
    end

    # it should never be nil.
    nil
  end

  def alias_generics(a, b)
    atype = get_type_of_generic(a)
    btype = get_type_of_generic(b)

    if not btype
      a = b = a
    end

    raise "unimplemented"

  end

end

#
# Logic for adding types
#

class Typer

  def initialize(ast)
    @ast = ast

    @types = Typetable.new
  end

  def produce_ast

    aliases_for_let_statements
    aliases_for_block_arguments

    constraints_for_function_application
    constraints_for_field_access

    @ast
  end

  def aliases_for_let_statements

  end

  def aliases_for_block_arguments

  end

  def constraints_for_function_application

  end

  def constraints_for_field_access

  end

end

