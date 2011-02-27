require 'ap'
require 'eventstore'
require 'mongo'
require 'uuid'

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rspec/expectations'
require 'rspec/mocks'

require 'support/array_enumeration_counter'

mongo_config = EventStore::Persistence::Mongodb::Config.instance
mongo_config.database = 'event_store_tests'

RSpec.configure do |config|
  config.fail_fast = true
  
  config.before :each do
    connection = Mongo::Connection.new(mongo_config.host, mongo_config.port, mongo_config.options)
    connection.db(mongo_config.database).collections.select {|c| c.name !~ /system/ }.each(&:drop)
  end
  
#  config.after :suite do
#    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
#  end
end