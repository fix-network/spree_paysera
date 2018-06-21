Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_paysera'
  s.version     = '0.29'
  s.summary     = 'Spree integration with Paysera.'
  s.description = 'Spree integration with Paysera.'

  s.author    = 'Donatas Jarmalovičius'
  s.email     = 'ddonatasjar@gmail.com'
  s.homepage  = 'https://github.com/donny741/'

  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '>= 3.1.0', '< 4.0'
  s.add_dependency 'spree_auth_devise', '>= 3.1.0', '< 4.0'
end