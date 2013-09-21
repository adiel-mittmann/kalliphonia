# -*- coding: utf-8 -*-

require 'segmenter.rb'
require 'starling.rb'
require 'epub-filter.rb'

segmenter = Segmenter.new()
starling = Starling.new(ARGV[0], segmenter)
EpubFilter.new(starling).run(ARGV[1], ARGV[2])

