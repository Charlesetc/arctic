
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
      elsif ast.token == :ident and iscapital(ast.data)
        handle_single_variant(ast)
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
        when "match"
          return triage_match(ast)
        end
      end

      if keyword and keyword.token == :ident and iscapital(keyword.data)
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

  def triage_match(ast)
    error_ast(ast, "match should have 2 children") if ast.children.length != 3
    matched = ast.children[1]
    triage(matched)

    block = ast.children[2]

    error_ast(ast, "match second child should be a block") unless block.class == Block
    error_ast(ast, "don't match with no branches please") unless block.children.length > 0
    error_ast(ast, "first line of match must be an arrow line") unless is_arrow(block.children[0])

    section = nil
    msection = nil
    msections = []

    block.children.each do |child|
      raise("block children are always parens") if child.class != Parens

      if is_arrow(child)
        msections << msection if section
        _, pattern, expression = child.children

        if pattern.class == Parens
          firstpattern = pattern.children[0]
          error_ast(pattern, "match pattern should be a variant") if firstpattern.nil?
          error_ast(pattern, "match pattern should be a variant") if firstpattern.token != :ident
          error_ast(pattern, "match pattern should be a variant") unless iscapital(firstpattern.data)
        elsif pattern.token == :ident
          error_ast(pattern, "match pattern should be a variant") unless iscapital(pattern.data)
          pattern = Parens.new([pattern], nil)
        else
          error_ast(pattern, "match pattern should be a variant") if pattern.class != Parens
        end

        section = [expression]

        msection = MatchSection.new(pattern, section)
      else
        section << child
      end
    end

    msections << msection if msection


    msections.each do |section|
      name = section.pattern.children[0].data
      arguments = section.pattern.children.drop(1)
      section.name = name
      section.arguments = arguments
    end

    handle_match(
      ast,
      matched,
      msections,
    )
  end

end

MatchSection = Struct.new(
  :pattern,
  :expressions,
  :name,
  :arguments,
  :expected_types,
  :return_type
)

def is_arrow(p)
  return false unless p.class == Parens
  first = p.children[0]
  return false unless first
  return false unless first.token == :ident
  return false unless first.data == "->"

  unless p.children.length == 3
    error_ast(p, "arrow should have two arguments")
  end
  unwrap_child?(p, 1)
  return true
end

def unwrap_child?(p, i)
  if p.class != Parens
    raise "can only unwrap parens' children"
  end
  c = p.children[i]

  if c.class == Parens and c.children.length == 1
    p.children[i] = c.children[0]
  end
end
