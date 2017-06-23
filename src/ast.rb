
# Token = Struct.new(:token, :data, :start, :finish)

def is_ident(tok, name)
  return false if tok.nil?
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

  def inspect_generics
    if data
      "#{token}(#{data})" + "_#{generic}"
    else
      token.inspect + "_#{generic}" # do you need this?
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

  def inspect_generics
    "#{kind}[#{children.map{|x| x.inspect_generics}.join(", ")}]" + "_#{generic}"
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

      # also iterate over let_in values
      if ast.is_a?(Let_in)
        rest << ast.value
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

  def inspect_generics
    inner = @children.map {|x| x.inspect_generics}.join(" ")
    "(#{inner})_#{generic}"
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

  def inspect_generics
    args = arguments.map{|x| x.inspect_generics}.join(", ")
    chlds = children.map{|x| x.inspect_generics}.join(", ")
    "#{kind}[#{args}][#{chlds}]_#{generic}"
  end
end

class Let_in < Block
  attr_reader :name, :value

  def initialize(name_tok, value, children)
    @children = children
    @name = name_tok.data
    @value = value
    @kind = :let_in

    @start = name_tok.start
    @finish = (children.last || name_tok).finish
  end

  def inspect
    "let_in #{name} #{value} #{children}"
  end

  def inspect_generics
    chlds = children.map{|x| x.inspect_generics}.join(", ")

    "let_in(#{name} #{value.inspect_generics} #{chlds})_#{generic}"
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

  def inspect_generics
    inner = @fields.map {|name, ast| "#{name} = #{ast.inspect_generics}" }
    "<#{inner.join(" , ")}>_#{generic}"
  end
end

