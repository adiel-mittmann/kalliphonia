# -*- coding: utf-8 -*-
require 'nokogiri'

class StarlingParser

  def initialize()
    @forms = []
  end

  def parse(html)
    xml = Nokogiri::HTML.parse(html)

    parent = nil
    xml.at_xpath("//body").xpath("*|text()").each do |node|
      case
      when node.type == Nokogiri::XML::Node::ELEMENT_NODE && node.name == "hr"
        node.name = "div"
        parent    = node
      when parent
        node.parent = parent
      end
    end

    xml.xpath("//div").each do |div|
      self.parse_section div
    end

    return self
  end

  def matching_forms(word)
    @forms.select{|form| form[:form].gsub(/['"]/, "") == word}
  end

  protected

  def add_form(form, pos, attrs)
    @forms += form
      .strip
      .split(/, *|\/\//)
      .map{|form| form.strip}
      .reject{|form| form.size == 0}
      .reject{|form| form =~ /\*/} # *ру'сск
      .reject{|form| form =~ /-/}  # подним-//подыму'
      .map{|form| {:form => form, :pos => pos}.merge(attrs)}
  end

  def parse_section(section)
    case
    when section.xpath(".//b[text()='Инфинитив:']").size == 1
      self.parse_verb_section section
    when section.xpath(".//th[text()='Мужской']").size == 1
      self.parse_adjective_section section
    when section.xpath(".//th[text()='Родительный']").size == 1 || section.xpath(".//th[text()='Именительный']").size == 1
      self.parse_noun_section section
    else
    end
  end

  def parse_noun_section(section)
    section.xpath("*|text()").each do |node|
      case node.type
      when Nokogiri::XML::Node::TEXT_NODE
        case
        when node.text =~ /[1-9] вариант:/
        else raise
        end
      when Nokogiri::XML::Node::ELEMENT_NODE
        case node.name
        when "table"
          self.parse_declinable node, :noun
        when "br"
        else
          raise
        end
      end
    end
  end

  def parse_adjective_section(section)
    degree = nil
    section.xpath("*|text()").each do |node|
      case node.type
      when Nokogiri::XML::Node::TEXT_NODE
        case
        when node.text =~ /[1-9] вариант:/
        when degree == :comparative
          forms = node.text.strip.split(/\/\//)
          case
          when forms.size == 4
            self.add_form forms[0], :adjective, {:degree => :comparative, :gender => :masc}
            self.add_form forms[1], :adjective, {:degree => :comparative, :gender => :fem}
            self.add_form forms[2], :adjective, {:degree => :comparative, :gender => :neut}
            self.add_form forms[3], :adjective, {:degree => :comparative, :number => :plural}
          when forms.size == 2
            self.add_form forms[0], :adjective, {:degree => :comparative}
            self.add_form forms[1], :adjective, {:degree => :comparative}
          end
        end
      when Nokogiri::XML::Node::ELEMENT_NODE
        case node.name
        when "table"
          self.parse_declinable node, :adjective
        when "b"
          case node.text
          when "Сравнительная степень:" then degree = :comparative
          else                               raise
          end
        when "br"
        else
          raise
        end
      end
    end
  end

  def parse_verb_section(section)
    type  = nil
    tense = nil
    voice = nil

    section.xpath("*|text()").each do |node|
      case node.type
      when Nokogiri::XML::Node::TEXT_NODE
        case
        when node.text =~ /[1-9] вариант:/ then
        when type == :infinitive           then self.add_form node.text, :verb, {:verbal_form => :infinitive}
        when type == :gerundive            then self.add_form node.text, :verb, {:verbal_form => :gerundive, :voice => voice}
        else                                    raise if node.text.strip.size != 0
        end

      when Nokogiri::XML::Node::ELEMENT_NODE
        case node.name
        when "b"
          case
          when node.text == "Деепричастие:" then type = :gerundive
          when node.text == "Инфинитив:"    then type = :infinitive
          else                                   raise
          end

        when "h2"
          case
          when node.text == "Действительный залог" then voice = :active
          when node.text == "Страдательный залог"  then voice = :passive
          else                                          raise
          end

        when "h3"
          case
          when node.text == "Настояще-будущее время"       then tense = :present_future
          when node.text == "Прошедшее время"              then tense = :past
          when node.text == "Повелительное наклонение"     then tense = :imperative
          when node.text == "Причастие настоящего времени" then tense = :present_participle
          when node.text == "Причастие прошедшего времени" then tense = :past_participle
          else                                                  raise
          end

        when "table"

          case tense
          when :present_participle, :past_participle
            self.parse_declinable node,       :adjective, {:voice => voice, :tense => tense}
          when :imperative
            table = self.read_table node, columns: 2, rows: 2, left_header: false
            self.add_form table[1][0],        :verb,      {:voice => voice, :tense => tense, :number => :singular, :person => :second}
            self.add_form table[1][1],        :verb,      {:voice => voice, :tense => tense, :number => :plural,   :person => :second}
          when :past
            table = self.read_table node, columns: 4, rows: 2, left_header: false
            self.add_form table[1][0],        :verb,      {:voice => voice, :tense => tense, :number => :singular, :gender => :masc}
            self.add_form table[1][1],        :verb,      {:voice => voice, :tense => tense, :number => :singular, :gender => :fem}
            self.add_form table[1][2],        :verb,      {:voice => voice, :tense => tense, :number => :singular, :gender => :neut}
            self.add_form table[1][3],        :verb,      {:voice => voice, :tense => tense, :number => :plural}
          when :present_future
            table = self.read_table node, columns: 3, rows: 4, left_header: true
            self.add_form table["1 лицо"][0], :verb,      {:voice => voice, :tense => tense, :number => :singular, :person => :first}
            self.add_form table["2 лицо"][0], :verb,      {:voice => voice, :tense => tense, :number => :singular, :person => :second}
            self.add_form table["3 лицо"][0], :verb,      {:voice => voice, :tense => tense, :number => :singular, :person => :third}
            self.add_form table["1 лицо"][1], :verb,      {:voice => voice, :tense => tense, :number => :plural,   :person => :first}
            self.add_form table["2 лицо"][1], :verb,      {:voice => voice, :tense => tense, :number => :plural,   :person => :second}
            self.add_form table["3 лицо"][1], :verb,      {:voice => voice, :tense => tense, :number => :plural,   :person => :third}
          else
            raise
          end

        when "br"
        else
          raise
        end
      end
    end
  end

  def read_table(table, columns:, rows:, left_header:, top_header: true)
    columns = columns..columns if columns.is_a?(Fixnum)
    rows    =    rows..rows    if    rows.is_a?(Fixnum)

    raise if !rows.include?(table.xpath("tr").size)

    data = {}
    table.xpath("tr").each_with_index do |tr, i|
      case
      when i == 0 && top_header
        raise if !columns.include?(tr.xpath("th").size)
      else
        raise if tr.xpath("th").size != (left_header ? 1 : 0)
        key = left_header ? tr.at_xpath("th").text : i
        data[key] = tr.xpath("td").to_a.map{|td| td.text}
      end
    end

    return data
  end

  def parse_declinable(node, pos, desc = {})
    cases   = {"Именительный"      => :nom,    "Родительный"       => :gen,
               "Родительный 2"     => :gen,    "Дательный"         => :dat,
               "Винительный неод." => :acc,    "Винительный одуш." => :acc,
               "Творительный"      => :ins,    "Предложный"        => :loc,
               "Предложный 2"      => :loc,    "Краткая форма"     => :nom}
    genders = {"Мужской"           => :masc,   "Женский"           => :fem,
               "Средний"           => :neut}
    numbers = {"Множ. число"       => :plural, "Ед. число"         => :singular}

    cols  = node.xpath("tr[position()=1]/th").map{|th| th.text}[1..-1]
    table = self.read_table node, columns: 3..5, rows: 2..9, left_header: true

    table.each do |key, forms|
      raise if !cases[key]
      forms.each_with_index do |form, i|
        case
        when genders[cols[i]] then self.add_form form, pos, desc.merge({:case => cases[key], :gender => genders[cols[i]], :number => :singular})
        when numbers[cols[i]] then self.add_form form, pos, desc.merge({:case => cases[key], :number => numbers[cols[i]]})
        else                       raise
        end
      end
    end
  end

end
