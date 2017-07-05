
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

    # With this if-check, we can add
    # definitions of operators by
    # define (+) [ ]
    # which is pretty sweet
    if item.children[1].class == Parens
      # TODO: assertions
      item.children[1] = item.children[1].children[0]
    end
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
      if ast.token == :ident and ast.data == "true"
        return handle_true(ast)
      elsif ast.token == :ident and ast.data == "false"
        return handle_false(ast)
      else
        handle_token(ast)
      end
    when ast.class == Parens
      keyword = ast.children[0]
      # assuming nonempty parens at the moment
      if keyword and keyword.token == :ident
        case keyword.data
        when "define"
          return triage_define(ast)
        when "if"
          return triage_if(ast)
        when "while"
          return triage_while(ast)
        when "inlay"
          return handle_inlay(ast)
        when "::"
          return triage_type_check(ast)
        when "_update"
          return triage_update(ast)
        end
      end

      if keyword and
         keyword.token == :ident and
         keyword.data[0] and
         keyword.data[0] < 'Z' and
         keyword.data[0] > 'A'
        # triage the arguments
        ast.children.drop(1).reverse.each { |c| triage(c) }
        return handle_variant(ast)
      end

      triage_function_call(ast)
    when ast.class == Object_literal
      triage_object_literal(ast)
    when ast.class == Block
      handle_block(ast)
    when ast.class == Dot_access
      triage_dot_access(ast)
    end
  end

  def triage_while(stmt)
    triage(stmt.children[1])

    stmt.children[2].children.each do |child|
      triage(child)
    end

    handle_while(stmt)
  end

  def triage_if(ifstmt)
    # conditional
    triage(ifstmt.children[1])

    # it's a block:
    ifstmt.children[2].children.each do |child|
      triage(child)
    end

    #something about entering/exiting the phonebook.
    if (elsestmt = ifstmt.children[3])
      elsestmt.children.each do |child|
        triage(child)
      end
    end

    handle_if(ifstmt)
  end

  def triage_dot_access(dot)
    triage(dot.child)
    handle_dot_access(dot)
  end

  def triage_type_check(check)
    # assert there are enough children
    triage(check.children[1])
    handle_type_check(check)
  end

  def triage_update(update)
    triage(update.children[1])
    triage(update.children[2])
    handle_update(update)
  end

  def triage_object_literal(object)
    object.fields.each { |_, f| triage_function_call f }
    handle_object_literal(object)
  end

end
