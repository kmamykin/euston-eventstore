require 'ap'
require 'euston-eventstore'

if RUBY_PLATFORM.to_s == 'java'
  require 'jmongo'
else
  require 'mongo'
end

if RUBY_PLATFORM.to_s == 'java'
  module Uuid
    def self.generate
      Java::JavaUtil::UUID.randomUUID().toString()
    end
  end
else
  require 'uuid'
  Uuid = UUID.new
end

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rspec/expectations'
require 'rspec/mocks'
require 'logger'

require 'support/array_enumeration_counter'

mongo_config = Euston::EventStore::Persistence::Mongodb::Config.instance
mongo_config.database = 'event_store_tests'
mongo_config.options = { :safe => true, :fsync => true, :journal => true } #, :logger => Logger.new(STDOUT)

RSpec.configure do |config|
  config.fail_fast = true

  config.before :each do
    connection = Mongo::Connection.from_uri 'mongodb://0.0.0.0:27017/', mongo_config.options
    db = connection.db(mongo_config.database)
    db.collections.select { |c| c.name !~ /system/ }.each { |c| db.drop_collection c.name }
  end
end
