# -*- coding: utf-8 -*-
require 'net/http'
require 'open-uri'
require 'gdbm-cache.rb'
require 'starling-parser.rb'
require 'segmenter.rb'
require 'russian.rb'

class Starling

  def initialize(cache: nil, use_html_cache: true, use_result_cache: true, use_ascii: false, fall_back: nil, clean_result_cache: false)
    @cache            = cache
    @use_html_cache   = use_html_cache
    @use_result_cache = use_result_cache
    @use_ascii        = use_ascii
    @fall_back        = fall_back
    @segmenter        = Segmenter.new()

    if clean_result_cache && cache
      @cache.delete{|key| key =~ /^result/}
    end
  end

  def run(text)
    delims, words = @segmenter.run(text)

    words = words.map do |word|
      result = self.process_word(word)
      print result + " "
      result
    end
    puts

    return @segmenter.assemble(delims, words)
  end

  protected

  def process_word(word)
    cached = self.get_cached_result(word)
    return cached if cached

    original = word
    result   = nil

    catch(:cancel) do
      throw :cancel if !Russian::only_russian_letters?(word)
      word = Russian::to_lower(word)

      forms = self.find_forms_for_word(word)
      if @fall_back && (forms.size == 0 || FURTHER.include?(word))
        forms += @fall_back.run(word).map{|form| {:form => form, :pos => :unknown}}
      end
      throw :cancel if forms.size == 0

      forms = forms.map{|form| self.diversify_diacritics(form)}
      form  = self.consolidate_forms(forms)
      form  = self.restore_case(form, original)
      form  = self.encode_diacritics(form) if !@use_ascii

      result = form
    end

    result = original if !result
    self.set_cached_result(original, result)
    return result
  end

  def find_forms_for_word(word)
    case
    when word =~ /ё/            then [{:form => word.gsub(/ё/, 'е"'), :pos => :unknown}]
    when REPLACE.has_key?(word) then REPLACE[word]
    else                             self.parse_forms_for_word(word) + (APPEND[word] || [])
    end
  end

  def parse_forms_for_word(word)
    StarlingParser.new.parse(self.get_html_for_word(word)).matching_forms(word)
  end

  def fetch_starling(word)
    uri  = "http://starling.rinet.ru/cgi-bin/morph.cgi?flags=wndnnnnp&root=config&word=#{URI::encode(word.encode("cp1251"))}"
    html = open(uri).read()
    @cache.put("html/#{word}.html", html) if @cache && @use_html_cache
    return reencode_html(html)
  end

  def reencode_html(html)
    html && html.encode("utf-8", "cp1251")
  end

  def get_html_for_word(word)
    self.get_cached_html(word) || self.fetch_starling(word)
  end

  def diversify_diacritics(form)
    i = case form[:pos]
        when :noun, :adjective
          case form[:case]
          when :gen then 2
          when :loc then 3
          else           1
          end
        when :verb  then 0
        else             4
        end

    form[:form]
      .gsub(/'/, DIACRITICS_TABLE[i][:a_ye])
      .gsub(/"/, DIACRITICS_TABLE[i][:a_yo])
  end

  def consolidate_forms(forms)
    return forms.first if forms.length == 1

    result = ""
    while forms.reduce(:+).length > 0
      symbols = forms.map{|form| form[0]}.keep_if{|c| ASCII_DIACRITICS.include?(c)}
      case
      when symbols.length > 0
        result << symbols.sort_by{|c| ASCII_DIACRITICS_ORDER.index(c)}.uniq.join
        forms = forms.map{|form| ASCII_DIACRITICS.include?(form[0]) ? form[1..-1] : form}
      else
        result << forms.first[0]
        forms   = forms.map{|form| form[1..-1]}
      end
    end

    return result
  end

  def restore_case(form, original)
    original = original.gsub("ё", "е").gsub("Ё", "Е")
    restored = ""

    m = 1
    (0..original.size - 1).each do |i|
      restored << original[i]
      while ASCII_DIACRITICS.include?(form[i + m]) do
        restored << form[i + m]
        m += 1
      end
    end

    return restored
  end

  def encode_diacritics(string)
    DIACRITICS_TABLE.each do |row|
      string = string.gsub(row[:a_ye], [row[:u_ye]].pack("U")).gsub(row[:a_yo], [row[:u_yo]].pack("U"))
    end
    return string
  end

  def get_cached_result(word)
    if @cache && @use_result_cache
      result = @cache.get("result/#{word}")
      result && result.force_encoding("utf-8")
    end
  end

  def set_cached_result(word, result)
    if @cache && @use_result_cache
      @cache.put("result/#{word}", result)
    end
  end

  def get_cached_html(word)
    if @cache && @use_html_cache
      reencode_html(@cache.get("html/#{word}.html"))
    end
  end

  def set_cached_html(word, html)
    if @cache && @use_html_cache
      @cache.put("html/#{word}.html", html)
    end
  end

  DIACRITICS_TABLE = [
                      {:u_ye => 0x0304, :u_yo => 0x0331,:a_ye => "!", :a_yo => "^"},
                      {:u_ye => 0x0346, :u_yo => 0x032a,:a_ye => "@", :a_yo => "&"},
                      {:u_ye => 0x0303, :u_yo => 0x0330,:a_ye => "#", :a_yo => "*"},
                      {:u_ye => 0x0308, :u_yo => 0x0324,:a_ye => "$", :a_yo => "("},
                      {:u_ye => 0x0307, :u_yo => 0x0323,:a_ye => "%", :a_yo => ")"},
                     ]

  ASCII_DIACRITICS = DIACRITICS_TABLE.map{|row| [row[:a_ye], row[:a_yo]]}.flatten
  ASCII_DIACRITICS_ORDER = (DIACRITICS_TABLE.map{|row| row[:a_ye]} + DIACRITICS_TABLE.map{|row| row[:a_yo]}).join

  REPLACE = {
    "все" => [{:form =>"все'", :pos => :adjective}, {:form => 'все"', :pos => :adjective}],
    "абы" => [{:form =>"а'бы", :pos => :uknown}],
    "денег" => [{:form => "де'нег", :pos => :noun, :case => :gen, :number => :plural}]
  }

  APPEND = {
    "моему" => [{:form => "мо'ему", :pos => :adjective}],
    "твоему" => [{:form => "тво'ему", :pos => :adjective}],
    "часа"  => [{:form => "часа'",  :pos => :noun}],
    "виду"  => [{:form => "виду'",  :pos => :noun}],
    "несмотря" => [{:form => "несмотря'",  :pos => :unknown}],
  }

  FURTHER = [
             "после", "кругом", "потом", "перед", "уже",
             "дабы", "коли",
             "больно", "мало", "нервно",
            ]

end
