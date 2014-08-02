# -*- coding: utf-8 -*-
class Russian

  UPPERCASE_ALPHABET = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
  LOWERCASE_ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"

  def self.to_lower(word)
    word.tr(UPPERCASE_ALPHABET, LOWERCASE_ALPHABET)
  end

  def self.only_russian_letters?(word)
    word.each_char do |c|
      return false if !LOWERCASE_ALPHABET.include?(c) && !UPPERCASE_ALPHABET.include?(c)
    end
    return true
  end

end
