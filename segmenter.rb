# -*- coding: utf-8 -*-
class Segmenter

  def initialize(text)
    @text = text
  end

  def each()
    while @text =~ /[\/,.!? ()\[\]{}#&=";_*:0-9\-\n\r—]+/

      yield :word,      $~.pre_match if $~.pre_match.length > 0
      yield :delimiter, $~.to_s
      @text = $~.post_match

    end

    if @text.length > 0
      yield :word, @text
    end

    @text = ''
  end

end
