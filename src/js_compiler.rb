
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

  def handle_type_check(check)
    check.compiled = check.children[1].compiled
  end

  def compile
    run_triage

    output = []

    output << js_global_functions

    @phonebook.each_expansion do |ast, argtypes|
      output << generate_function_definition(ast, argtypes)
    end

    output << generate_main_function
    toplevel_extras(output)
    output << call_main_function

    output.join "\n"
  end

  def js_global_functions
    inner = @phonebook.function_literals.map do |name, phone|
      inner = phone.expanded.keys.map do |types|
        "\"#{types.join(',')}\": #{specific_fp(name, types)}"
      end.join(",")
      "#{name}: {#{inner}}"
    end.join(",")
    "const global_functions = {#{inner}};"
  end

  def toplevel_extras(output)
    @phonebook.toplevel_extras do |filename, name, ast|
      unless ast.type.class == FunctionType
        triage(ast)
      end
      # this is because there are some functions
      # that are never looked at.
      # we skip those
      if (ast.compiled or ast.type.class != FunctionType)
        output << "var #{filename}_#{name} = #{ast.compiled}"
      end
    end
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

  def call_main_function
    "console.log(main());"
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

  def handle_update(update)
    var = update.children[1]
    if var.class == Parens
      # TODO: more asserts:
      var = var.children[0]
    end
    update.compiled = "(#{var.compiled} = #{update.children[2].compiled})"
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
      arg_calls = arguments.map { |x| partial_call(x) }.join
      parens.compiled = first.compiled + arg_calls

      # If greater
      if first.type.arity <= arguments.length
        parens.compiled += ".call()"
      end
    end
  end

  def triage_the_specific_call(function_type)
    @phonebook.lookup_function(
      function_type,
      method: :fetch
    ) do |ast, arguments, _|
      triage(ast)
    end
  end

  def handle_block(block)
    name = block.type.names[0]
    raise "expected block ast to have single name" unless block.type.names.length == 1

    args_to_new_closure = [name] + @phonebook.lookup_found(name)
    block.compiled = "new_closure(#{args_to_new_closure.join(",")})"
  end

  def generate_function_definition(block, argtypes)
    items = block.children
    items.each do |child|
      triage(child) unless child.compiled
    end
    label_return(items[-1]) if items[-1]

    inner = items.map { |x| "\t#{x.compiled};\n" }.join

    name = block.type.names[0]
    raise "expected block ast to have single name" unless block.type.names.length == 1

    args = @phonebook.lookup_found(name)
    args += block.arguments.map {|x| x.data}
    "function #{specific_fp(name, argtypes)}(#{args.join(",")}) {\n#{inner}}"
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

  def handle_inlay(inlay)
    unless inlay.children[1] and inlay.children[1].token == :string
      error_ast(inlay, "inlay's first argument should be a string")
    end
    inlay.compiled = inlay.children[1].data
  end

  def handle_single_variant(ident)
    ident.compiled = "{#{ident.data}: null}"
  end

  def handle_variant(parens)
    name = parens.children[0].data
    arguments = parens.children.drop(1).map do |child|
      child.compiled
    end.join(",")

    parens.compiled = "{#{name}: [#{arguments}]}"
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

  def define_label(item)
    return unless item.class == Parens
    return unless item.children[0]
    return unless item.children[0].token == :ident
    return unless item.children[0].data == "define"
    item.compiled = item.compiled + " ; return #{item.children[1].data}"
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
    return if define_label(item)
    item.compiled = 'return ' + item.compiled
  end

end
