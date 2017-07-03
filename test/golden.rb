
require './src/files'
require './src/typer'
require './src/grammar'
require './src/js_compiler'
require './src/phonebook'
require 'testrocket'


suites = [
  :typer,
  :js_compiler,
]

def record(suite)
  Dir.glob("test/golden/#{suite}/*.brie") do |filename|
    out = self.send(suite, filename)
    File.write(filename + ".out", out)
  end
end

def check(suite, name: "*")
  Dir.glob("test/golden/#{suite}/#{name}.brie") do |filename|
    print "  #{File.basename(filename, ".brie")} -- "
    out = self.send(suite, filename)
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
def typer(filename)
  file = SourceFile.new(filename)
  Typer.new(file).run
  file.ast.inspect_types
end

def js_compiler(filename)
  file = SourceFile.new(filename)
  phonebook = Phonebook.new
  Typer.new(file, phonebook: phonebook).run
  JsCompiler.new(file, phonebook).compile
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
    if ARGV[1]
      check(suite, name: ARGV[1])
    else
      check(suite)
    end
  end
end
