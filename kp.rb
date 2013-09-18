# -*- coding: utf-8 -*-

require 'segmenter.rb'
require 'starling.rb'
require 'html-filter.rb'

segmenter = Segmenter.new()
starling = Starling.new(ARGV[0], segmenter)
puts HtmlFilter.new(starling).run(File.read(ARGV[1]))
