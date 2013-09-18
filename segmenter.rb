# -*- coding: utf-8 -*-
class Segmenter

  def initialize()
  end

  def each(text)
    @text = text

    while @text =~ /[\/,.!? ()\[\]{}#&=";_*:0-9\-\n\r\t— ]+/

      yield :word,      $~.pre_match if $~.pre_match.length > 0
      yield :delimiter, $~.to_s
      @text = $~.post_match

    end

    if @text.length > 0
      yield :word, @text
    end

    @text = ''
  end

  def run(text)
    delims = []
    words  = []
    self.each(text) do |type, text|
      case
      when type == :word
        delims << "" if delims.length == 0
        words  << text
      else
        delims << text
      end
    end
    delims << "" if words.length > 0 && words.length != delims.length - 1
    return delims, words
  end

  def assemble(delims, words)
    return "" if delims.length == 0
    result = ""
    words.each_index do |i|
      result << delims[i]
      result << words[i]
    end
    result << delims[-1]
    return result
  end

end
