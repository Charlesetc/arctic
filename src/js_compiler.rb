
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
    # We handle the require's definitions
    # by going over the 'toplevel extras'
    req.compiled = ''
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
    items = @main_function.children

    # I should delete these lines:
    items.each do |child|
      triage(child) unless child.compiled
    end
    label_return(items[-1]) if items[-1]

    inner = items.map { |x| "\t#{x.compiled};\n" }.join

    "function main() {\n#{inner}}"
  end

  def before_triage(ast)
    raise "already compiled" if ast.compiled
  end

  def handle_token(token)
    case token.token
    when :ident
      token.compiled =
        if @phonebook.is_toplevel?(@file.name, token.data)
          @file.name + "_" + token.data
        else
          token.data
        end
    when :string
      token.compiled = token.data.inspect
    else
      error_ast(token, "do not know how to handle token #{token.token}")
    end
  end

  def handle_true(token)
    token.compiled = "true"
  end

  def handle_false(token)
    token.compiled = "false"
  end

  def handle_while(stmt)
    condition = stmt.children[1].compiled
    inner = stmt.children[2].children.map do |c|
      c.compiled + ';'
    end.join("\n")
    stmt.compiled = "while (#{condition}) {#{inner}}"
  end

  def handle_if(ifstmt)

    condition = ifstmt.children[1].compiled
    inner_if = ifstmt.children[2].children.map do |c|
      c.compiled + ';'
    end.join("\n")

    inner_else = if ifstmt.children[3]
                   ifstmt.children[3].children.map do |c|
                     c.compiled + ';'
                   end.join("\n")
                 else
                   ''
                 end
    ifstmt.compiled = "if (#{condition}) {#{inner_if}} else {#{inner_else}}"

  end

  def handle_define(item, toplevel:)
    item.compiled =
      "var #{item.children[1].data} = #{item.children[2].compiled}"
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
    items = block.children
    items.each do |child|
      triage(child) unless child.compiled
    end
    label_return(items[-1]) if items[-1]

    inner = items.map { |x| "\t#{x.compiled};\n" }.join

    args = @phonebook.lookup_found(block.type)
    args += block.arguments.map {|x| x.data}
    "function #{specific_fp(block.type.name, argtypes)}(#{args.join(",")}) {\n#{inner}}"
  end

  def handle_object_literal(object)
    inner = object.fields.map do |name, ast|
      "#{name}: #{ast.compiled}"
    end.join(", ")
    object.compiled = "{#{inner}}"
  end

  def handle_dot_access(dot)
    dot.compiled = dot.child.compiled + "." + dot.name
  end


  #
  # Helpers
  #

  def while_label(item)
    return unless item.class == Parens
    return unless item.children[0]
    return unless item.children[0].token == :ident
    return unless item.children[0].data == "while"
    item.compiled = item.compiled + ' ; return __unit'
    true
  end


  def if_label(item)
    return unless item.class == Parens
    return unless item.children[0]
    return unless item.children[0].token == :ident
    return unless item.children[0].data == "if"


    if item.children[3]
      ret1 = item.children[2].children.last
      label_return(ret1)
      ret2 = item.children[3].children.last
      label_return(ret2)

      # recompile the last part to
      # include the return...
      handle_if(item)
    else
      item.compiled = item.compiled + ' ; return __unit'
    end
    true
  end

  def label_return(item)
    return if if_label(item)
    return if while_label(item)
    item.compiled = 'return ' + item.compiled
  end

end
