# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "boursorama"

Gem::Specification.new do |s|
  s.summary = "Boursorama Ruby API"
  s.name = "boursorama"
  s.author = "Maël Clérambault"
  s.email =  "mael@clerambault.fr"
  s.homepage = "http://hanklords.github.com/boursorama"
  s.files = %w(lib/boursorama.rb LICENSE README.md)
  s.version = Boursorama::VERSION
end
