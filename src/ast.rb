
# Token = Struct.new(:token, :data, :start, :finish)

def is_ident(tok, name)
  tok.token == :ident and tok.data == name
end

Separator = Struct.new(:ast, :post)

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

  def inspect_types
    if data
      "#{token}(#{data})" + "_#{type}"
    else
      token.inspect + "_#{type}" # do you need this?
    end
  end

  # def type <-- defined in typer.rb!

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

  def inspect_types
    "#{kind}[#{children.map{|x| x.inspect_types}.join(", ")}]" + "_#{type}"
  end

  def iterate
    # do nothing
    # only used in Parens
  end

  def all_iterables(&block)
    @children.each(&block)
  end

  def collect(cls: Ast, post:nil)
    yield self if self.is_a?(cls)

    rest = self.children.clone
    until rest.empty?
      ast = rest.pop

      # This little bit is used to have
      # callbacks after the completion of an
      # ast's children
      #
      # Perhaps there is a cleaner way to do this
      # (certainly with recursion) but it's not
      # THAT ugly so we'll leave it in for now.
      if ast.is_a?(Separator)
        ast.post.call(ast.ast) if ast.post
      end

      if ast.is_a?(cls) # otherwise it's a token
        yield ast
      end

      if ast.is_a?(Ast)
        rest << Separator.new(ast, post)
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

  def inspect_types
    inner = @children.map {|x| x.inspect_types}.join(" ")
    "(#{inner})_#{type}"
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

  def inspect_types
    args = arguments.map{|x| x.inspect_types}.join(", ")
    chlds = children.map{|x| x.inspect_types}.join(", ")
    "#{kind}[#{args}][#{chlds}]_#{type}"
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

  def inspect_types
    inner = @fields.map {|name, ast| "#{name} = #{ast.inspect_types}" }
    "<#{inner.join(" , ")}>"
  end
end

