MRuby::Gem::Specification.new('mruby-tnetstrings') do |spec|
  spec.license = 'MIT'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'mruby TNetString parser/writer'
  spec.add_dependency 'mruby-sprintf'
  spec.add_dependency 'mruby-kernel-ext'
end
