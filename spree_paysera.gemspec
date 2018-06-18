Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_paysera'
  s.version     = '0.10'
  s.summary     = 'Spree integration with Paysera.'
  s.description = 'Spree integration with Paysera.'

  s.author    = 'Donatas Jarmalovičius'
  s.email     = 'ddonatasjar@gmail.com'
  s.homepage  = 'https://github.com/'

  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '~> 3.0'
end