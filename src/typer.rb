
require 'set'
require_relative './utils'
require_relative './ast'

#
# Types
#

class Generic < Struct.new(:id, :start, :finish)
  def to_s
    id.to_s
  end
  def inspect
    to_s
  end
end

## Any type either inherits from
# `Unknown`, `Literal`, or `Open`.

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

class Unknown < Type ; end

class Literal < Type

  attr_accessor :subtype

  # valid subtypes:
  # :integer
  # :string
  # :object

  def initialize(subtype)
    @subtype = subtype
  end

end

class Function_literal < Type

  attr_accessor :takes, :returns

  def initialize(takes:, returns:)
    @takes = takes
    @returns = returns
  end

end

class Closed_object < Type

  attr_accessor :fields

  def initialize(fields)
    @fields = fields
  end
end

class Open_function < Function_literal
end

class Open_object < Type

  attr_accessor :fields

  # .fields is a dictionary from
  # the name of the field to it's
  # generic. This is important
  # because then the inference of
  # the fields works transparently
  # as we infer the type of the
  # generic.

  def initialize(fields)
    @fields = fields
  end
end



$generic_counter = 0

def new_generic(start, finish)
  g = Generic.new($generic_counter, start, finish)
  $generic_counter += 1
  g
end

#
# Ast
#

# reopening the class to add
# type-specific features 
class Token
  
  # lazily make the generics!
  def generic
    if @generic
      @generic
    else
      @generic = new_generic(@start, @finish)
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

    [nil, nil]
  end

  def get_type_or_unknown(generic)
    set, type = get_type_of_generic(generic)
    if set.nil? and type.nil?
      set = Set.new([generic])
      type = Unknown.new
    elsif set.nil? or type.nil?
      raise "Did not prepare for this situation"
    end
    [set, type]
  end

  def already_has(type)
    @type_mapping.map {|k, v| k.include?(type)}.any?
  end

  def error_types(a, b)
    # in the future, use line numbers.
    raise "Type error: #{a.inspect} and #{b.inspect} conflict"
  end

  def constrain_generic(generic, constrained)
    set, type = get_type_or_unknown(generic)

    @type_mapping[set] = constrain(type, constrained)
  end

  def alias_generics(a, b)
    aset, atype = get_type_of_generic(a)
    bset, btype = get_type_of_generic(b)

    # if they are the same don't do anything
    return if aset == bset and not aset.nil?

    if not btype and not atype
      @type_mapping[Set.new([a, b])] = Unknown.new
    elsif btype and atype
      @type_mapping.delete_if do |k, v|
        k == aset or k == bset
      end
      ctype = constrain(atype, btype)
      @type_mapping[aset.union bset] = ctype
    else

      if btype
        aset, bset = bset, aset
        atype, btype = btype, atype
        a, b = b, a
      end
      begin
        # quite understandably,
        # you can't mutate the
        # keys of a hash in place.
        v = @type_mapping.delete aset
        aset << b
        @type_mapping[aset] = v
      end
    end
  end

  # Refactor this into a nice class-based system.
  def constrain(type, constrained)
    return constrained if type.class == Unknown
    return type if constrained.class == Unknown
    return type if type == constrained

    case ## Why the actual **** does this fail
         ## using type.class here on
         ## literal_and_open_function.brie?
    when type.class == Function_literal

      if constrained.class == Open_function
        # I'm saying:
          # Whatever was previously called in this function
          # has to be able to be reconciled with the literal.
        _, argument_type = get_type_or_unknown(type.takes)
        constrain_generic(constrained.takes, argument_type)

        alias_generics(type.returns, constrained.returns)
        return type
      end

      raise "I don't think logic should get here."
      # you will have to change this if you ever want to make
      # objects pass as functions
      error_types(type, constrained) unless constrained.class == Function_literal
      alias_generics(type.takes, constrained.takes)
      alias_generics(type.returns, constrained.returns)
      return type ## ?
    when type.class == Open_function
      if constrained.class == Open_function
        alias_generics(type.takes, constrained.takes)
        alias_generics(type.returns, constrained.returns)
        return type
      elsif constrained.class == Function_literal
        return constrain(constrained, type) # Basically only works with Function_literal
      else
        error_types(type, constrained)
      end
    when type.class == Literal # all other literals
      error_types(type, constrained)
    when type.class == Open_object
      if constrained.class == Open_object
        # merge, alias on duplicates:
        new_fields = type.fields.clone
        constrained.fields.map do |k, v|
          if new_fields[k]
            alias_generics(new_fields[k], v)
          else
            new_fields[k] = v
          end
        end
        return Open_object.new(new_fields)
      else
        # Either error or go to Closed_object
        return constrain(constrained, type)
      end
    when type.class == Closed_object
      error_types(type, constrained) unless constrained.class == Open_object

      # I think aliasing is the right move here.
      constrained.fields.each do |k, v|
        # you can make this a better error message
        # in the future:
        error_types(type, constrained) unless type.fields[k]
        alias_generics(type.fields[k], v)
      end
      type
    else
      raise "I don't know how to constrain this class: #{type.class}"
    end
  end

end

#
# Logic for keeping track of name stack
#


class Aliaser

  def initialize(types)
    @typetable = types
    @names = []
  end

  def get(name)
    @names.map { |x| x[name] }.last
  end

  def add(stack)
    @names << stack
  end

  def drop
    @names.pop
  end

  def post
    lambda do |a|

      aliased(a)

      return unless a.is_a?(Block)
      drop
    end
  end

  def record_let(ast)
    return unless ast.is_a?(Let_in)
    @typetable.alias_generics(ast.generic, ast.value.generic)

    add({ast.name => ast.generic})
  end

  def record_block(ast)
    return unless ast.class == Block

    arguments = ast.arguments.map do |a|
      [a.data, a.generic]
    end.to_h

    add(arguments)
  end

  def aliased(ast)

    # includes everything, and tokens
    ast.collect(cls: Token) do |tok|

      # this is kind of sketchy, but here's what's happening:
      #
      # `aliased` is called on every `collect` in `aliases_for_names`
      # we only alias the first time it's called, and we do this
      # by checking if to see if the token already has it's type in
      # the type table. (so it's important not much comes before aliases_for_names)
      # but aliases_for_names is a very important function, and no other typing
      # things really make sense without having the names taken care of...
      # so it's reasonable to expect this to be the first one.
      if (generic = get(tok.data)) and not @typetable.already_has(tok.generic)
        # puts "HI " + tok.to_s
        @typetable.alias_generics(tok.generic, generic)
      end
    end

  end
end


#
# Logic for adding types
#

class Typer

  def initialize(root)
    # blame me if you want
    # but don't take it out
    # on my friends:
    $generic_counter = 0
    @root = root

    @typetable = Typetable.new
  end

  def unification

    # clean up tree first!
    # get rid of extra parentheses

    convert_let_statements
    aliases_for_names # (let statements and block arguments)
    convert_function_calls

    constraints_for_token_literals
    constraints_for_function_application
    constraints_for_block_literals
    # constraints_for_function_returns

    constraints_for_object_literals
    constraints_for_field_access

    @typetable
  end

  def stringify_types
    @typetable.type_mapping.map do |k, v|
      [k.to_a, v]
    end.to_h.inspect
  end

  private

    def convert_let_statements
      # this is a tree operation that
      # transforms 'define x 3' within a
      # block to let_in x 3 [ ]
      # with the rest of the lines of the block in the
      #
      # This means that (define x 3) + 2 or something
      # is invalid because 'define' is just a let statement.
      #
      # Maybe don't do this within class definitions?

      @root.collect(cls: Block) do |block|
        i = 0
        while i != block.children.length do
          child = block.children[i]
          i += 1
          next if child.class != Parens
          next if not is_ident(child.children[0], "define")

          # construct new child
          let_in = Let_in.new(child.children[1], child.children[2], block.children[(i)..block.children.length])

          # ignore the rest of the children
          block.children = block.children[0...i-1]
          # add back in new child
          block.children << let_in
        end
      end

    end

    def convert_function_calls
      @root.collect(cls: Parens) do |parens|
        length = parens.children.length
        if length > 2
          parens.children = [
            Parens.new(parens.children[0...length-1],parens.children[1]),
            parens.children[length-1],
          ]
        end
      end
    end

    def aliases_for_names
      aliaser = Aliaser.new(@typetable)

      # cls: Ast by default
      @root.collect(post: aliaser.post) do |ast|
        aliaser.record_let(ast)
        aliaser.record_block(ast)
      end
    end

    def constraints_for_token_literals
      @root.collect(cls: Token) do |tok|
        if tok.class == Token
          if tok.token == :ident and tok.data.valid_integer?
            @typetable.constrain_generic(tok.generic, Literal.new(:integer))
          elsif tok.token == :string
            @typetable.constrain_generic(tok.generic, Literal.new(:string))
          end
        end
      end
    end

    def constraints_for_function_application
      @root.collect(cls: Parens) do |parens|
        if parens.children.length == 2
          @typetable.constrain_generic(
            parens.children[0].generic,
            Open_function.new(
              takes: parens.children[1].generic,
              returns: parens.generic,
            )
          )
        elsif parens.children.length == 1
          @typetable.alias_generics(
            parens.children[0].generic,
            parens.generic,
          )
        end
      end
    end

    def constraints_for_block_literals
      @root.collect(cls: Block) do |block|
        if block.class == Block
          last_generic = block.children.last.generic
          block.arguments.reverse.each do |arg|
            g = new_generic(last_generic.start, last_generic.finish)
            @typetable.constrain_generic(
              g,
              Function_literal.new(
                takes:arg.generic,
                returns:last_generic,
              )
            )
            last_generic = g
          end
          @typetable.alias_generics(block.generic, last_generic)
        end
      end
    end

    def constraints_for_function_returns

      post = lambda do |parens|
        # we only care about function application
        if parens.children.length == 2
          # The function's type is not being
          # constrained here.
          # But! The parens' value is constrained
          # to work with the function's return.


          _, type = @typetable.get_type_of_generic(parens.children[0].generic)
          raise "Expected function" unless [Function_literal, Open_function].include? type.class

          _, return_type = @typetable.get_type_of_generic(type.returns)

          # NOTE: This theoretically makes two entries in the
          # table for the same (i.e. integer) type.
          # However, it makes sense to have two entries for
          # open objects.
          #
          # Should I copy the types if it's a function or
          # object? \_(*,*)_/ Who knows!
          @typetable.constrain_generic(
            parens.generic,
            return_type
          )

        end

      end

      @root.collect(post: post, cls: Parens) do |parens|
      end

    end

    def constraints_for_object_literals
      @root.collect(cls: Object_literal) do |object|
        fields = object.fields.map do |k, v|
          [k, v.generic]
        end.to_h
        @typetable.constrain_generic(
          object.generic,
          Closed_object.new(fields)
        )
      end
    end

    def constraints_for_field_access
      @root.collect(cls: Dot_access) do |dotted|

        @typetable.constrain_generic(
          dotted.child.generic,
          Open_object.new({dotted.name => dotted.generic})
        )
      end
    end

end

