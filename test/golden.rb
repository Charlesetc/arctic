
require '../src/typer'
require '../src/grammar'
require 'testrocket'


suites = [
  :typer,
]

def record(suite)
  Dir.glob("golden/#{suite}/*.brie") do |filename|
    out = self.send(suite, File.read(filename))
    File.write(filename + ".out", out)
  end
end

def check(suite)
  Dir.glob("golden/#{suite}/*.brie") do |filename|
    out = self.send(suite, File.read(filename))
    begin
      expected = File.read(filename + ".out").chomp
    rescue
      expected = "FILE NOT FOUND"
    end
    if out != expected
      puts "expected: " + expected
      puts "got:      " + out
    end
    +-> { out == expected }
  end
end

## Suite runners
def typer(input)
  t = Tokenizer.new(input)
  g = Grammar.new(t.tokens)
  ty = Typer.new(g.produce_ast)
  ty.produce_ast

  ty.stringify_types
end



## Main
case ARGV[0]
when 'record'
  suites.each do |suite|
    record suite
  end
when 'check'
  suites.each do |suite|
    puts "#{suite}:"
    check suite
  end
end
