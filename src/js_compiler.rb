
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

  def handle_require(req)
  end

  def compile
    run_triage

    output = []

    @phonebook.each_expansion do |ast, argtypes|
      output << generate_function_definition(ast, argtypes)
    end

    # this is supposed to be where we handle
    # things that have been defined on the toplevel
    # but aren't functions. (Function calls require
    # extra logic to compile-time-dispatch on their types.)
    # one example is imported objects.
    @phonebook.toplevel_extras do |filename, name, ast|
      triage(ast)
      output << "var #{filename}_#{name} = #{ast.compiled}"
    end
    output << generate_main_function

    output.join "\n"
  end

  def generate_main_function
    inner = @main_function.children.map do |child|
      "\t" + child.compiled + "\n"
    end.join
    "function main() {\n#{inner}}"
  end

  def before_triage(ast)
    raise "already triaged" if ast.compiled
  end

  def handle_token(token)
    case token.token
    when :ident
      token.compiled = token.data
    when :string
      token.compiled = token.data.inspect
    else
      error_ast(token, "do not know how to handle token #{token.token}")
    end
  end

  def handle_define(item, toplevel:)
    item.compiled =
      "var #{item.children[1].data} = #{item.children[2].compiled};"
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
        # fill in the arguments
        inner = arguments.map { |x| x.compiled }.join(",")
        parens.compiled = first.compiled + ".fill_in_arguments(#{inner})"
      else
        # if equal:
        # now we have all the arguments,
        # but it still could be a closure.

        # if it's a unit type:
        arguments = [] if first.type.arity < arguments.length

        # need the arguments because it's based on their
        # types. Could be improved a bit.
        args = arguments.map { |x| x.compiled }.join(",")
        news = ".fill_in_arguments(#{args})"
        news += prepare_function_call(
          first.type.add_arguments(arguments)
        )
        parens.compiled = first.compiled + news
      end
    end
  end

  def prepare_function_call(function_type)
    @phonebook.lookup_function(
      function_type,
      method: :fetch
    ) do |ast, arguments|
      triage(ast)

      ".call(#{specific_fp(function_type.name, arguments)})"
    end
  end

  def handle_block(block)
    found = @phonebook.lookup_found(block.type).join(",")
    block.compiled = "new_closure().fill_in_arguments(#{found})"
  end

  def generate_function_definition(block, argtypes)
    inner = block.children.map do |child|
      triage(child) unless child.compiled
      "\t" + child.compiled + "\n"
    end.join

    args = @phonebook.lookup_found(block.type)
    args += block.arguments.map {|x| x.data}
    "function #{specific_fp(block.type.name, argtypes)}(#{args.join(",")}) {\n#{inner}}"
  end

end
