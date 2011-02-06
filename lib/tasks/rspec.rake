require 'rspec/core'
require 'rspec/core/rake_task'
require 'rspec/expectations'
require 'rspec/mocks'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = %w[--format Fuubar --color]
  spec.pattern = "spec/**/*_spec.rb"
end