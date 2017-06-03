

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

BREAK = ".{}()[]<> \t\n:;".chars

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
    while not done?
      case
      when char == '.'
        advance
        if not BREAK.include? char
          ident = read_ident
          save :dotaccess, data: ident
        else
          save :dot
        end
      when char == '['
        advance
        save :open_square
      when char == ']'
        advance
        save :close_square
      when char == '\n'
        advance
        save :newline
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
      when (char == ' ' or char == '\t')
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
    while (not done?) and not (BREAK.include? char)
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

t = Tokenizer.new(ARGF.read.chomp)
p t.tokens
