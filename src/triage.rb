
require_relative './utils'

# triage.rb

module Triage

  def index_file
    # get initial definitions
    @file.ast.children.each do |item|
      raise "this shouldn't happen" unless item.class == Parens
      keyword = item.children[0]

      if keyword.token != :ident
        error_ast(item, "expecting valid top-level identifier")
      end

      # top level items
      case keyword.data
      when "define"
        triage_define(item, toplevel: true)
      when "require"
        handle_require(item)
      else
        error_ast(item, "expecting valid top-level identifier")
      end
    end
  end

  def triage_define(item, toplevel: false)
    triage(item.children[2])
    handle_define(item, toplevel: toplevel)
  end

  def run_triage
    index_file

    @main_function = @phonebook.lookup(@file.name, "main")
    error_ast(@file.ast, "no main function") unless @main_function

    # execute_function(main_function.type)
    # main_function.children.each { |c| triage_function_call(c) }
    @main_function.children.each { |c| triage(c) }
  end

  def triage_function_call(parens)
    before_triage(parens)
    raise "triage_function_call called on not-parens" unless parens.class == Parens
    parens.children.reverse.each { |c| triage(c) }
    handle_function_call(parens)
  end

  def triage(ast)
    before_triage(ast)
    case
    when ast.class == Token
      handle_token(ast)
    when ast.class == Parens
      keyword = ast.children[0]
      # assuming nonempty parens at the moment
      if keyword and keyword.token == :ident
        case keyword.data
        when "define"
          return triage_define(ast)
        when "if"
          raise "unimplemented"
          return handle_if()
        end
      end
      triage_function_call(ast)
    when ast.class == Object_literal
      handle_object_literal(ast)
    when ast.class == Block
      handle_block(ast)
    when ast.class == Dot_access
      handle_dot_access(ast)
    end
  end

end
