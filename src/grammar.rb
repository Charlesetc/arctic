
require_relative './ast'

BREAK = ".{}(,)[]<=> \t\n:;".chars

class Tokenizer

  def initialize(text)
    @text = text
    @index = 0
    @tokens = []
    @last = 0
  end

  def char
    @text[@index]
  end

  def peek
    @text[@index+1]
  end

  def advance
    @index += 1
  end

  def done?
    @index == @text.length
  end

  def save(token, data: nil)
    @tokens << Token.new(token, data, @last, @index)
    @last = @index
  end

  def tokens
    until done?
      case
      when char == '.'
        advance
        if BREAK.include? char
          save :dot
        else
          ident = read_ident
          save :dotaccess, data: ident
        end
      when char == '['
        advance
        save :open_square
      when char == ']'
        advance
        save :close_square
      when char == '<'
        advance
        save :open_angle
      when char == '>'
        advance
        save :close_angle
      when char == "\n"
        advance
        save :newline
      when char == '='
        advance
        save :equals
      when char == ','
        advance
        save :comma
      when char == ':'
        advance
        save :colon
      when char == ';'
        advance
        save :semicolon
      when char == '('
        advance
        save :open_round
      when char == ')'
        advance
        save :close_round
      when char == '"'
        string = read_quotes(char)
        save :string, data: string
      when (char == ' ' or char == "\t")
        advance
        @last = @index
      when (char == '-' and peek == '-')
        until done? or char == "\n"
          advance
        end
        advance
        save :newline
      else
        ident = read_ident
        save :ident, data: ident
      end
    end

    @tokens
  end

  def read_ident
    store = char
    advance
    until done? or BREAK.include?(char)
      store += char
      advance
    end
    store
  end

  def read_quotes(quote)
    advance
    store = ''
    while (not done?) and (char != quote)
      store += char
      advance
    end
    advance
    store
  end
end

class Grammar

  def initialize(tokens)
    @ast = Root.new(tokens)
  end

  def produce_ast
    collect do |x|
      parentheses x
    end

    collect do |x|
      lambdas x
    end

    # turn root with
    # some newlines
    # into root
    # of parens
    level_toplevel(@ast)

    collect do |x|
      object_literals x
    end

    collect do |x|
      dot_access x
    end

    collect do |x|
      binary_operator(x, ["or"])
    end
    collect do |x|
      binary_operator(x, ["and"])
    end

    collect do |x|
      binary_operator(x, "+-")
    end

    collect do |x|
      binary_operator(x, "*/")
    end

    @ast
  end

  def collect(&block)
    @ast.collect(&block)
  end

  # states
  Searching = 0
  Arguments = 1
  Lines = 2
  def lambdas(ast)

    count = 0
    state = Searching

    # used to construct the block:
    arguments = []
    lines = []
    line = []

    ast.iterate do |child|
      case state
      when Searching
        if child.token == :colon
          state = Arguments
          nil
        elsif child.token == :open_square
          count = 1
          state = Lines
          nil
        else
          child
        end
      when Arguments
        if child.token == :open_square
          count = 1
          state = Lines
          nil
        elsif child.token == :ident
          arguments << child
          nil
        else
          error_ast(child,
          'expected an identifier when listing arguments to a block')
        end
      when Lines
        if child.token == :open_square
          count += 1
        elsif child.token == :close_square
          raise 'Got unexpected close square bracket' if count.zero?
          count -= 1
        end

        if count.zero?
          lines << Parens.new(line, child) unless line.empty?
          block = Block.new(lines, arguments, child)
          line = []             # just added these: -- check in the future
          lines = []
          state = Searching
          block
        elsif child.token == :newline and count == 1
          lines << Parens.new(line, child) unless line.empty?
          line = []
          nil
        else
          line << child
          nil
        end
      end
    end
    raise 'Got unexpected open square bracket' if count != 0
  end

  def level_toplevel(ast)
    lines = []
    line = []
    ast.children.each do |child|
      if child.token == :newline
        unless line.empty?
          lines << Parens.new(line, line[0])
          line = []
        end
      else
        line << child
      end
    end
    ast.children = lines
  end

  # states defined above
  # Searching = 0
  # Lines = 2
  def parentheses(ast)
    count = 0
    line = []
    state = Searching
    ast.iterate do |child|
      case state
      when Searching
        if child.token == :open_round
          count = 1
          state = Lines
          nil
        else
          child
        end
      when Lines
        if child.token == :open_round
          count += 1
        elsif child.token == :close_round
          raise 'Got unexpected close parenthesis' if count.zero?
          count -= 1
        end

        if count.zero?
          val = Parens.new(line, child)
          line = []
          state = Searching
          val
        else
          line << child
          nil
        end
      end
    end
    raise 'Got unexpected open parenthesis' if count != 0
  end

  # states defined above
  # Searching = 0
  # Lines = 2
  Fields = 4
  Equals = 5
  def object_literals(ast)
    count = 0
    field = nil
    fields = {}
    state = Searching
    ast.iterate do |child|
      case state
      when Searching
        if child.token == :open_angle
          count = 1
          state = Fields
          nil
        else
          child
        end
      when Fields
        unless child.token == :ident
          error_ast(child,
          'expected an identifier to start a field of this object')
        end

        field = child.data
        fields[field] = []
        state = Equals
        nil
      when Equals
        unless child.token == :equals
          error_ast(child,
          'expected an equals sign after the start an object field')
        end
        state = Lines
        nil
      when Lines
        if child.token == :open_angle
          count += 1
        elsif child.token == :close_angle
          raise 'Got unexpected close angle bracket' if count.zero?
          count -= 1
        end

        if count.zero?
          obj = Object_literal.new(fields, child)
          fields = {}
          state = Searching
          obj
        elsif child.token == :comma and count == 1
          state = Fields
          nil
        else
          fields[field] << child
          nil
        end
      end
    end
    raise 'Got unexpected open angle bracket' if count != 0
  end

  def dot_access(ast)
    last_child = nil
    # This basically looks ahead one for the
    # dot token and then wraps the last one
    # if it's there.
    ast.iterate do |child|

      if child.token == :dotaccess
        child = Dot_access.new(child, last_child)
        last_child = nil
      end

      last = last_child
      last_child = child
      last
    end
    # don't forget the last one
    ast.iterate_follow do
      ast.children << last_child
    end
  end

  # this is doable.
  # search for a plus or minus.
  # If it's there, divide the symbols
  # into two groups, as arguments to the
  # plus or minus.
  # then do the same search on the group to the right
  # maybe then make this generic for /, *, and, or, etc.
  def binary_operator(ast, operators)

    i = 0
    index = nil

    ast.iterate do |child|
      # remove this line for right associativity
      unless index
        if child.token == :ident and operators.include?(child.data)
          index = i
        end
      end
      i += 1
      child
    end

    ast.iterate_follow do
      return unless index
      return if index == 0

      length = ast.children.length
      if index == length - 1
        error_ast(ast, "Found operator without right side")
      end

      left = ast.children[0..index-1]
      right = ast.children[index+1..length]
      ast.children = [
        ast.children[index],
        Parens.new(left, ast),
        Parens.new(right, ast),
      ]
    end
  end
end

def error_ast(ast, reason)
  STDERR.puts "Error: #{reason}", ast
  exit(0)
 end
