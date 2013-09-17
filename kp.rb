# -*- coding: utf-8 -*-

require 'segmenter.rb'
require 'starling.rb'

starling = Starling.new(ARGV[0])
segmenter = Segmenter.new(File.read(ARGV[1]))

segmenter.each do |type, text|
  case
  when type == :word
    STDOUT.write(starling.get(text))
  else
    STDOUT.write(text)
  end
end
