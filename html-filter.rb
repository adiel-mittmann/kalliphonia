class HtmlFilter

  def initialize(converter)
    @converter = converter
  end

  def run(html)
    @html   = html
    @result = ""
    @text   = ""
    @s      = 0

    @html.each_char do |c|
      case
      when @s == 0
        case
        when c == "<"
          self.flush_text()
          @s = 1
          self.output(c)
        else
          @text << c
        end
      when @s == 1
        case
        when c == ">"
          @s = 0
          self.output(c)
        else
          self.output(c)
        end
      end
    end

    self.flush_text()

    return @result

  end

  def flush_text
    return if @text.length == 0
    @text = @converter.run(@text)
    self.output(@text)
    @text = ""
  end

  def output(s)
    @result << s
    STDOUT.write(s)
    STDOUT.flush
  end

end
