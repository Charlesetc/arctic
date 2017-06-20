
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
  Generic.new($generic_counter, start, finish)
  $generic_counter += 1
end


#
# Ast
#

# reopening the class to add
# type-specific features 
class Token
  
  # lazily make the types!
  def type
    if @type
      @type
    else
      @type = new_generic(@start, @finish)
    end
  end

end

class Typetable

  attr_reader :type_mapping

  def initialize

    # map from sets of Generics to their type.
    #
    # this is the source of truth.
    @type_mapping = {}
  end

  def get_type_of_generic(generic)
    @type_mapping.each do |k, v|
      if k.include? generic
        return [k,v]
      end
    end

    # it should never be nil.
    [nil, nil]
  end

  def alias_generics(a, b)
    aset, atype = get_type_of_generic(a)
    bset, btype = get_type_of_generic(b)

    # if they are the same don't do anything
    return if aset == bset and not aset.nil?

    if not btype and not atype
      @type_mapping[Set.new([a, b])] = Unknown
    elsif btype and atype
      @type_mapping.delete(aset)
      @type_mapping.delete(bset)
      ctype = constrain atype btype
      @type_mapping[a.union b] = ctype
    else
      if btype
        aset, bset = bset, aset
        atype, btype = btype, atype
      end
      # now atype is not nil
      aset << b
    end
  end

  def constrain(atype, btype)
    raise "unimplemented"
  end

end

#
# Logic for adding types
#

class Typer

  def initialize(root)
    @root = root

    @types = Typetable.new
  end

  def produce_ast

    # clean up tree first!
    # get rid of extra parentheses

    convert_let_statements

    aliases_for_let_statements
    aliases_for_block_arguments

    constraints_for_function_application
    constraints_for_field_access

    @root
  end

  def print_types
    p @types.type_mapping
  end

  private

    def convert_let_statements

      @root.collect(cls: Block) do |block|
        i = 0
        while i != block.children.length do
          child = block.children[i]
          i += 1
          next if child.class != Parens
          next if not is_ident(child.children[0], "define")

          # construct new child
          new_scope = Block.new(block.children[(i)..block.children.length] || [], [], child)
          child.children << new_scope
          child.children[0].data = 'let_in'

          # ignore the rest of the children
          block.children = block.children[0..(i-1)]
        end
      end

    end

    def aliases_for_let_statements

      @root.collect(cls: Parens) do |parens|
        if is_ident(parens.children[0], "let_in")
          @types.alias_generics(parens.children[2].type, parens.type)

          # includes everything and Tokens.
          parens.collect(cls: Token) do |tok|
            # if the token is the same as the ident from the 'let_in'
            # then alias the two
            if is_ident(tok, parens.children[1].data)
              @types.alias_generics(tok.type, parens.type)
            end
          end

        end
      end
    end

#     def aliases_for_block_arguments
#       # This code assumes that 'alias_generics'
#       # is only called before by aliases_for_let_statements.
#       @root.collect(cls: Block) do |block|
#         block.arguments.each do |argument|
#           p argument
#         end
#       end
#     end

    def constraints_for_function_application

    end

    def constraints_for_field_access

    end

end

