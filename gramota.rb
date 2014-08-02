# -*- coding: utf-8 -*-
require 'nokogiri'
require 'net/http'
require 'open-uri'
require 'russian.rb'

class Gramota

  def initialize(cache: nil, use_result_cache: true)
    @html_cache       = cache
    @use_result_cache = use_result_cache
    @result_cache     = {}
  end

  def run(word)
    return @result_cache[word] if @use_result_cache && @result_cache.has_key?(word)

    html   = self.retrieve_cached_html(word) || self.http_fetch(word)
    xml    = Nokogiri::HTML.parse(html)
    result = []
    result += self.extract(xml, word, "http://www.gramota.ru/slovari/info/lop/")
    result += self.extract(xml, word, "http://www.gramota.ru/slovari/info/bts/")

    @result_cache[word] = result if @use_result_cache
    return result
  end

  protected

  def reencode_html(html)
    html && html.encode("utf-8", "cp1251")
  end

  def retrieve_cached_html(word)
    reencode_html(@html_cache && @html_cache.get("html/#{word}.html"))
  end

  def http_fetch(word)
    uri  = "http://www.gramota.ru/slovari/dic/?all=x&word=#{URI::encode(word.encode("cp1251"))}"
    html = open(uri).read()
    @html_cache.put("html/#{word}.html", html) if @html_cache
    return reencode_html(html)
  end

  def extract(xml, word, url)
    a = xml.at_xpath("//h2/a[@href='#{url}']")
    return [] if !a

    b = a.parent.next_element.xpath("b")
    return [] if b.size == 0

    return b.map{ |b|

      s = b.xpath("*|text()").map{ |node|
        case node.type
        when Nokogiri::XML::Node::TEXT_NODE
          node.text
        when Nokogiri::XML::Node::ELEMENT_NODE
          node.text + "'"
        end
      }.join

      s = Russian::to_lower(s)
        .gsub(/ *[1-9]$/, "") # "и 1"
        .gsub(/, *$/, "")     # "со,"
        .gsub(/ *$/, "")      # "с "
        .gsub("ё", 'е"')      # "ещё"
        .gsub(/^ +/, "")      # " НЕ'РВНО"
        .gsub(/\.$/, "")      # "спаси'бо."

      s.gsub(/['"]/, "") == word ? s : nil

    }.reject{|alt| alt == nil}.uniq
  end


end
