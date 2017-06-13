
Token = Struct.new(:token, :data, :start, :finish)

class Token
  def inspect
    if data
      "#{token.inspect}(#{data})"
    else
      token.inspect
    end
  end
end

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
      else
        ident = read_ident
        save :ident, data: ident
      end
    end

    @tokens
  end

  def read_ident
    store = ''
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

class Ast

  # token is only used to pun with Tokens
  attr_accessor :children, :kind, :token, :start, :finish

  def initialize(children, kind)
    @kind = kind
    @children = children

    @start = @children.first.start
    @finish = @children.last.finish
  end

  def inspect
    "#{kind}#{children}"
  end

  def iterate
    # do nothing
    # only used in Parens
  end

  def all_iterables(&block)
    @children.each(&block)
  end

end

class Root < Ast
  def initialize(children)
    @kind = :root
    @children = children

    if @children.first
      @start = @children.first.start
      @finish = @children.last.finish
    else
      @start = 0
      @finish = 0
    end
  end

  def iterate(&block)
    @children.map!(&block)
    @children.select! {|c| not c.nil?}
  end
end

class Parens < Root
  def initialize(children, backup_child)
    @kind = :parens
    @children = children

    @start = (@children.first || backup_child).start
    @finish = (@children.last || backup_child).finish
  end

  def inspect
    inner = @children.map {|x| x.inspect}.join(" ")
    "(#{inner})"
  end
end

class Block < Ast
  attr_reader :arguments
  
  def initialize(children, arguments, backup_child)
    @children = children
    @arguments = arguments
    @kind = :block

    @start = (@arguments.first || @children.first || backup_child).start
    @finish = (@children.last || backup_child).finish
  end

  def inspect
    "#{kind}#{arguments}#{children}"
  end
end

class Object_literal < Ast
  attr_reader :fields

  def initialize(field_map, backup_child)
    field_map.each { |k, v| field_map[k] = Parens.new(v, nil) }
    @fields = field_map

    @start = @fields.values.map { |x| x.start }.min
    @finish = @fields.values.map { |x| x.finish }.max
  end

  def all_iterables
    @fields.each {|_name, ast| yield ast }
  end

  def inspect
    inner = @fields.map {|name, ast| "#{name} = #{ast.inspect}" }
    "<#{inner.join(" , ")}>"
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
    collect do |x|
      object_literals x
    end
    @ast
  end

  def collect
    yield @ast
    rest = @ast.children.clone
    until rest.empty?
      ast = rest.pop 
      
      if ast.is_a?(Ast) # otherwise it's a token
        yield ast
        ast.all_iterables { |a| rest << a }
      end
    end
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
end

def error_ast(ast, reason)
  STDERR.puts "Error: #{reason}", ast
  exit(0)
 end
