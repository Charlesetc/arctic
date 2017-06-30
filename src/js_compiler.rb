
require_relative './triage'
require_relative './utils'

class Token
  attr_accessor :compiled
end

class JsCompiler

  include Triage

  def initialize(file, phonebook)
    @phonebook = phonebook
    @file = file
  end

  def compile
    run_triage
    @main_function.children.map do |child|
      child.compiled
    end
  end

  def before_triage(ast)
    raise "already triaged" if ast.compiled
  end

  def handle_token(token)
    case token.token
    when :ident
      token.compiled = token.data
    when :string
      token.compiled = token.inspect
    else
      error_ast(token, "do not know how to handle token #{token.token}")
    end
  end

  def handle_define(item)
    item.compiled = "
    var #{item.children[1].data} = #{item.children[2].compiled};
    "
  end

  def handle_function_call(parens)
    first = parens.children[0]
    case parens.children.length
    when 0
      parens.compiled = "__unit"
    when 1
      parens.compiled = first.compiled
    else
      error_ast_type(first, expected: "a Function") unless first.type.class == FunctionType
      arguments = parens.children[1...parens.children.length]

      # If greater
      if first.type.arity > arguments.length
        # get the closure
        if first.type.arguments.empty?
          parens.compiled = "new_closure()" # also close over variables...
        else
          parens.compiled = first.compiled
        end
        # fill in the arguments
        inner = arguments.map { |x| x.compiled }.join(",")
        parens.compiled += ".fill_in_arguments([#{inner}])"
      else
        # if equal:
        # now we have all the arguments,
        # but it still could be a closure.

        # if it's a unit type:
        arguments = [] if first.type.arity < arguments.length

        # need the arguments because it's based on their
        # types. Could be improved a bit.
        parens.compiled = prepare_function_call(
          first.type.add_arguments(arguments)
        )
      end
    end
  end

  def prepare_funciton_call(function_type)
    @phonebook.lookup_function(
      function_type,
      method: :fetch
    ) do |ast, arguments|
      args = arguments.map { |x| x.compiled }.join(",")
      argtypes = arguments.map { |x| x.type }

      ast.compiled +
      ".fill_in_arguments(#{args})" +
      ".call(#{specific_fp(function_type.name, argtypes)})"
    end
  end

end
