require 'pry'

class JSXify
  DEBUG = false

  def initialize(code)
    @code = code
  end

  def go
    walk(:phase1)
    walk(:phase2)
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
      if (tag = line.match(/<(\w+)/))
        @out << (' ' * count(line)) + '</' + tag[1] + '>'            # insert closing tag
      elsif line.match(/{$/)
        @out << (' ' * count(line)) + "},\n"                         # insert closing bracket
      end
    when :line
      line.sub!(/React\.DOM\.(\w+)/, '<\1>')                         # a react dom element (change to a tag)
      line.sub!(/(\s+)([A-Z][\w\.]+)$/, '\1<\2>')                    # most likely a component (change to a tag)
      line.sub!(/> \{\},/, '>')                                      # empty brackets after a tag (remove)
      line.gsub!(/@(\w+)/, 'this.\1')                                # change @foo to this.foo
      if @indents.last.to_s =~ /[^=]>$/                              # inside a tag
        if line =~ /^\s+'.+'$|\s+".+"$/                              # literal text body
          line.sub!(/^(\s+)'(.+)'$/, '\1\2')                         # single-quoted tag content (remove quotes)
          line.sub!(/^(\s+)"(.+)"$/, '\1\2')                         # double-quoted tag content (remove quotes)
        elsif line =~ /^\s+this\./                                   # probably a js expression body
          line.sub!(/^(\s+)(this\..+)$/, '\1{\2}')                   # wrap in brackets
        end
      end
      line.sub!(/for (\w+), (\w+) in (.+)$/, '\3.map((\1, \2) => {') # for thing, index in things
      line.sub!(/for (\w+) in ([^\s]+)$/, '\2.map((\1) => {')        # for thing in things
      line.sub!(/: ->$/, '() {')                                     # function with no args
      line.sub!(/: \(([^\)]+)\)\s*->$/, '(\1) {')                    # function with args
      line.sub!(/"([^"]*#\{[^"]*)"/) do
        '`' + $1.gsub(/#\{(.+?)\}/, '${\1}') + '`'                   # string interpolation
      end
      if line =~ /\s+<[\w\.]+> \{\s*\w+: /                           # one-line tag and props
        line.gsub!(/(\w+): (['"`])(.+?)\2,?/, '\1=\2\3\2')           # string props
        line.gsub!(/(\w+): ([^ ,]+),?/, '\1={\2}')                   # js expression props
      end
      if @indents.last =~ /classnames$/ && line =~ /: /
        @out.last << ', ' unless @out.last =~ /\(\{$/
        @out.last << line.strip
      else
        @out << line
      end
    end
  end

  def phase2(op, line)
    case op
    when :line
      if @indents.last =~ /<[\w.]+>/ && (m = line.match(/^\s+(\w+): (.+)/)) && @out.last =~ />$/
        value = m[2]
        value.sub!(/,$/, '')
        value = "{#{value}}" unless value =~ /\A'.*'\z|\A".*"\z/
        @out.last.sub!(/>$/, " #{m[1]}=#{value}>")
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
      if line =~ /^\s*$/
        @out << line
        next
      end
      @last_indent = @indent
      @indent = count(line)
      if @indent > @last_indent
        @indents << @out.last.dup
        if send(walker, :indent, line) != false
          send(walker, :line, line)
        else
          @indents.pop # not real
        end
      elsif @indent < @last_indent
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

if (arg = ARGV.first)
  coffee = File.read(ARGV.first)
else
  coffee = STDIN.read
end
puts JSXify.new(coffee.split(/\n/)).go.join("\n")
