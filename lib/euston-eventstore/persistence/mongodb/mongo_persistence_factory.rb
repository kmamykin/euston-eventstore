if RUBY_PLATFORM.to_s == 'java'
  module JMongo
    module BasicDBObjectExtentions
      include HashKeys
    end
  end

  require 'jmongo'
else
  require 'mongo'
end

module Euston
  module EventStore
    module Persistence
      module Mongodb
        class MongoPersistenceFactory
          def self.build
            config = Config.instance
            options = {}
            options.merge!(:logger => config.logger) unless config.logger.nil?

            @connection ||= Mongo::Connection.from_uri config.uri, options

            MongoPersistenceEngine.new @connection.db(config.database)
          end
        end
      end
    end
  end
end
