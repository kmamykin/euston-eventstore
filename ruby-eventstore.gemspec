# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'eventstore/version'

Gem::Specification.new do |s|
  s.name        = 'ruby-eventstore'
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

  s.add_dependency 'bson_ext', '~> 1.1'
  s.add_dependency 'rake',     '~> 0.8'
  s.add_dependency 'jeweler',  '~> 1.4'
  s.add_dependency 'mongoid',  '~> 2.0.0.beta'
  s.add_dependency 'uuid',     '~> 2.3'

  s.add_development_dependency 'awesome_print',      '~> 0.2'
  s.add_development_dependency 'autotest',           '~> 4.2'
  s.add_development_dependency 'cucumber',           '~> 0.9'
  s.add_development_dependency 'database_cleaner',   '~> 0.6'
  s.add_development_dependency 'rspec-core',         '~> 2.0'
  s.add_development_dependency 'rspec-expectations', '~> 2.0'
  s.add_development_dependency 'rspec-mocks',        '~> 2.0'
end
