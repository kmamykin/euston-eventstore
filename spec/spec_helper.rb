require 'ap'
require 'eventstore'
require 'mongoid'
require 'uuid'

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rspec/expectations'
require 'rspec/mocks'

Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |support| require support }

Mongoid.configure do |config|
  config.autocreate_indexes = false
  config.logger = Logger.new('mongo.log')
  config.master = Mongo::Connection.new('localhost', 27017, :logger => config.logger).db('protean')
  config.persist_in_safe_mode = true
  config.use_utc = true
end

RSpec.configure do |config|
  config.fail_fast = true
  config.after :suite do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
  end
end