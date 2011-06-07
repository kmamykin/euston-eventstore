# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'eventstore/version'

Gem::Specification.new do |s|
  s.name        = 'eventstore'
  s.version     = EventStore::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Lee Henson']
  s.email       = ['lee.m.henson@gmail.com']
  s.summary     = %q{}
  s.description = %q{}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'activesupport', '~> 3.0'
  s.add_dependency 'bson_ext',      '~> 1.1'    unless RUBY_PLATFORM.to_s == 'java'
  s.add_dependency 'jeweler',       '~> 1.4'
  s.add_dependency 'jmongo'                     if RUBY_PLATFORM.to_s == 'java'
  s.add_dependency 'json',          '~> 1.5'
  s.add_dependency 'mongo',         '~> 1.3.1'  unless RUBY_PLATFORM.to_s == 'java'
  s.add_dependency 'rake',          '~> 0.8'
  s.add_dependency 'uuid',          '~> 2.3'

  s.add_development_dependency 'awesome_print'
  s.add_development_dependency 'fuubar'
  s.add_development_dependency 'rspec-core',         '~> 2.6'
  s.add_development_dependency 'rspec-expectations', '~> 2.6'
  s.add_development_dependency 'rspec-mocks',        '~> 2.6'
end
