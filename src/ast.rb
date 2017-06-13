
# Token = Struct.new(:token, :data, :start, :finish)

def is_ident(tok, name)
  tok.token == :ident and tok.data == name
end

class Token

  attr_accessor :data, :token, :start, :finish

  def initialize(token, data, start, finish)
    @token = token
    @data = data
    @start = start
    @finish = finish
  end

  def inspect
    if data
      "#{token.inspect}(#{data})"
    else
      token.inspect
    end
  end

end

class Ast < Token

  attr_accessor :children, :kind

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

  def collect(cls: Ast)
    yield self if self.is_a?(cls)

    rest = self.children.clone
    until rest.empty?
      ast = rest.pop

      if ast.is_a?(cls) # otherwise it's a token
        yield ast
        ast.all_iterables { |a| rest << a } if ast.is_a?(Ast)
      elsif ast.is_a?(Ast)
        ast.all_iterables { |a| rest << a }
      end

    end
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

