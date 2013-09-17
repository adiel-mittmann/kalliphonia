# -*- coding: utf-8 -*-
require 'net/http'
require 'open-uri'

require 'file-system-cache.rb'

class Starling

  RUSSIAN_UPPERCASE_ALPHABET = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
  RUSSIAN_LOWERCASE_ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"

  def initialize(cache_path)
    @file_cache = FileSystemCache.new(cache_path);
  end

  def get(word)

    original = word

    result = original
    catch(:done) do

      word = word.tr(RUSSIAN_UPPERCASE_ALPHABET, RUSSIAN_LOWERCASE_ALPHABET)

      word.each_char do |c|
        throw :done if !RUSSIAN_LOWERCASE_ALPHABET.include?(c)
      end

      # If Russian was always this easy...
      if word =~ /ё/
        result = word
        throw :done
      end

      forms = self.get_forms_for_word(word)
      form = self.consolidate_forms(forms)
      restored = self.restore_case(form, original)
      result = self.encode_diacritics(restored)

    end

    return result

  end

  protected

  def get_html_for_word(word)
    key = "#{word}.html"

    html = @file_cache.get(key)
    if !html
      mangled = URI::encode(word.encode("cp1251"))
      uri = "http://starling.rinet.ru/cgi-bin/morph.cgi?flags=wndnnnnp&root=config&word=#{mangled}"
      data = open(uri).read()
      @file_cache.put(key, data)
      html = data
    end

    return html.force_encoding("cp1251").encode("utf-8")
  end

  def get_forms_for_word(word)

    html  = self.get_html_for_word(word)

    forms = html
      .lines
      .map   {|line| line.strip}
      .select{|line| line =~ /^<td/ || line =~ /^<b>/}
      .map   {|line| line.gsub(/<b>.*<\/b>/, "")}
      .map   {|line| line.gsub(/<[^<]+>/, "")}
      .map   {|line| line.split(/, */)}
      .flatten
      .reject{|line| line =~ /\*/}
      .map   {|line| line.strip}
      .sort
      .uniq

    map = Hash.new([])
    forms.each do |form|
      map[form.gsub(/['"]/, "")] += [form]
    end

    return map[word]

  end

  def consolidate_forms(forms)

    case
    when forms.length == 0
      throw :done

    when forms.length == 1
      form = forms.first

    else

      form = ""
      while forms.reduce(:+).length > 0
        symbols_at = forms.each_with_index.map{|form, i| ["'", '"'].include?(form[0]) ? i : -1}.reject{|i| i == -1}
        case
        when symbols_at.length > 0
          symbols = forms.map{|form| form[0]}.values_at(*symbols_at).uniq
          throw :done if symbols.length > 1
          forms = forms.each_with_index.map{|form, i| symbols_at.include?(i) ? form[1..-1] : form}
          form << symbols.first
        else
          letters = forms.map{|form| form[0]}.uniq
          throw :done if letters.length > 1
          forms = forms.map{|form| form[1..-1]}
          form << letters.first
        end
      end
    end

    return form

  end

  def restore_case(form, original)

    restored = ""
    throw :done if form.gsub(/["']/, "").length != original.length

    while original.length > 0
      case
      when ["'", '"'].include?(form[0])
        restored << form[0]
        form = form[1..-1]
      else
        restored << original[0]
        form = form[1..-1]
        original = original[1..-1]
      end
    end

    restored << form if form.length > 0

    return restored

  end

  def encode_diacritics(string)
    string.gsub(/е"/, "ё").gsub(/'/, [0x0301].pack("U"))
  end

end
