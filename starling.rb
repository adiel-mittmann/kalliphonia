# -*- coding: utf-8 -*-
require 'net/http'
require 'open-uri'

require 'file-system-cache.rb'

class Starling

  RUSSIAN_UPPERCASE_ALPHABET = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
  RUSSIAN_LOWERCASE_ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"

  EXCEPTIONS = {
    "все" => "все!",
    "что" => "чтo^",
    "то" => "то^"
  }

  UNINFLECTABLES = {
    "для"     => ["для`"],
    "потом"   => ["пото'м"],
    "пока"    => ["пока'"],
    "ли"      => ["ли`"],
    "более"   => ["бо'лее"],
    "не"      => ["не`"],
    "спасибо" => ["спаси'бо"],
    "после"   => ["по'сле"],
    "на"      => ["на`"],
    "теперь"  => ["тепе'рь"],
    "когда"   => ["когда'"],
    "едва"    => ["едва'"],
    "мало"    => ["ма'ло"],
    "больно"  => ["бо'льно"],
  }

  DIACRITICS = ["'", '"', '!', '`', '^', "&"]
  DIACRITICS_REGEXP = Regexp.new("([" + DIACRITICS.reduce(:+) + "])")

  def initialize(cache_path, segmenter)
    @file_cache = FileSystemCache.new(cache_path);
    @segmenter  = segmenter
  end

  def run(text)

    delims, words = @segmenter.run(text)

    i = 0
    while i < words.length

      word = words[i]
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

        case
        when EXCEPTIONS.has_key?(word)
          form = EXCEPTIONS[word]

        else

          forms = UNINFLECTABLES[word]
          forms = [] if !forms

          forms, same = self.get_forms_for_word(word, forms)
          form        = self.consolidate_forms(forms, same)
        end

        restored  = self.restore_case(form, original)
        result    = self.encode_diacritics(restored)

      end

      words[i] = result

      i += 1

    end

    return @segmenter.assemble(delims, words)

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

  def get_forms_for_word(word, extra)

    html  = self.get_html_for_word(word)

    forms = html
      .lines
      .map   {|line| line.strip}
      .select{|line| line =~ /^<td/ || line =~ /^<b>/}
      .map   {|line| line.gsub(/<b>.*<\/b>/, "")}
      .map   {|line| line.gsub(/<[^<]+>/, "")}
      .map   {|line| line.split(/, *|\/\//)}
      .reject{|line| line.map{|word| word =~ /\*/ || word == "-"}.reduce(false){|a,b| a || b}}
      .map   {|line| line.map{|word| word.strip }}
      .uniq

    forms << extra

    same_form = {}

    forms_letters = forms.map{|os| os.map{|o| o.gsub(DIACRITICS_REGEXP, "")}}
    forms_letters.each_with_index do |options, i|
      next if options.length == 1
      next if options.uniq.length != 1
      next if forms_letters.map{|os| os.include?(options.first)}.reject{|a| !a}.length != 1
      same_form[options.first] = true
    end

    forms = forms.flatten.uniq

    map = Hash.new([])
    forms.each do |form|
      map[form.gsub(/['"]/, "")] += [form]
    end

    return map[word], same_form[word]

  end

  def consolidate_forms(forms, same)

    case
    when forms.length == 0
      throw :done

    when forms.length == 1
      form = forms.first

    else

      form = ""
      while forms.reduce(:+).length > 0
        symbols_at = forms.each_with_index.map{|form, i| DIACRITICS.include?(form[0]) ? i : -1}.reject{|i| i == -1}
        case
        when symbols_at.length > 0
          symbols = forms.map{|form| form[0]}.values_at(*symbols_at).uniq
          forms = forms.each_with_index.map{|form, i| symbols_at.include?(i) ? form[1..-1] : form}
          case
          when symbols.length == 1
            form << symbols.first
          when ["'\"", "\"'"].include?(symbols.reduce(:+))
            form << "!"
          when ["'`", "`'"].include?(symbols.reduce(:+))
            form << "^"
          else
            throw :done
          end
        else
          letters = forms.map{|form| form[0]}.uniq
          throw :done if letters.length > 1
          forms = forms.map{|form| form[1..-1]}
          form << letters.first
        end
      end
    end

    if same
      form = form.gsub(DIACRITICS_REGEXP, "\\1&")
    end

    return form

  end

  def restore_case(form, original)

    restored = ""
    throw :done if form.gsub(DIACRITICS_REGEXP, "").length != original.length

    while original.length > 0
      case
      when DIACRITICS.include?(form[0])
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
    string
      .gsub(/е"/, "ё")
      .gsub(/'/, [0x0301].pack("U"))
      .gsub(/е!/, "ё" + [0x0301].pack("U"))
      .gsub(/`/, [0x0300].pack("U"))
      .gsub(/\^/, [0x0302].pack("U"))
      .gsub(/&/, [0x0323].pack("U"))
  end

end
