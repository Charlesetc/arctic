
require 'set'

#
# Types
#


class Type

  def constrain_to_literal(kind)
    return Literal.new(kind)
  end

  def constrain_with_field(field, value)
    return Open_object.new(field, value)
  end

end

class Literal < Type
  
  def initialize(kind)
    @kind = kind
  end


end

class Function < Type

end

class Open_object < Type

end

#
# Ast
#

# reopening the class to add
# type-specific features 
class Ast
  

end

class Typeholder

  def initialize

    # map from sets of Generics to their type.
    @types = {}
    @types = {}

  end

end

#
# Logic for adding types
#

class Typer

  def initialize(ast)
    @ast = ast

    @types = {}
  end

  def produce_ast

    add_types

    @ast
  end

  def add_types

  end

end

