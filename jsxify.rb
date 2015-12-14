require 'pry'

class JSXify
  DEBUG = false

  def initialize(code)
    @code = code
  end

  def go
    walk(:phase1)
    @code
  end

  private

  def phase1(op, line)
    case op
    when :indent
      if @indents.last =~ /classnames$/ && line =~ /: /
        @out.last << '({'
        false
      end
      true
    when :pre_dedent
      @out.last << '})' if @indents.last =~ /classnames$/ && @out.last !~ /\}\)$/
    when :dedent
      tag = line.match(/<(\w+)/)
      @out << (' ' * count(line)) + '</' + tag[1] + '>' if tag
    when :line
      line.sub!(/React\.DOM\.(\w+)/, '<\1>')
      if @indents.last =~ /classnames$/ && line =~ /: /
        @out.last << ', ' unless @out.last =~ /\(\{$/
        @out.last << line.strip
      else
        @out << line
      end
    end
  end

  def count(line)
    line.match(/^ */).to_s.size
  end

  def walk(walker)
    @out = []
    @indents = []
    @indent = 0
    @code.each do |line|
      p @indents
      p line
      if line =~ /^\s*$/
        @out << line
        next
      end
      @last_indent = @indent
      @indent = count(line)
      if @indent > @last_indent
        @indents << @out.last.dup
        if send(walker, :indent, line)
          send(walker, :line, line)
        else
          @indents.pop # not real
        end
      elsif @indent < @last_indent
        puts
        puts 'dedenting'
        send(walker, :pre_dedent, line)
        loop do
          top = @indents.pop
          send(walker, :dedent, top)
          break if count(top) == @indent
        end
        send(walker, :line, line)
      else
        send(walker, :line, line)
      end
    end
    @code = @out
  end
end

coffee = File.read(ARGV.first)

puts JSXify.new(coffee.split(/\n/)).go.join("\n")
