# -*- coding: utf-8 -*-
$:.push(File.join(File.dirname(__FILE__)))
require 'starling.rb'
require 'html-filter.rb'
require 'epub-filter.rb'
require 'gramota.rb'

if ARGV.size != 4
  STDERR.puts "ruby kp.rb GRAMOTA-DB STARLING-DB INPUT-EPUB OUTPUT-EPUB"
  exit
end

gramota  = Gramota.new(cache: GdbmCache.new(ARGV[0]))
starling = Starling.new(cache: GdbmCache.new(ARGV[1]), fall_back: gramota)
EpubFilter.new(starling).run(ARGV[2], ARGV[3])
