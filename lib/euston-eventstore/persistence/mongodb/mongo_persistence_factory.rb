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
            connection = ::Mongo::Connection.new(config.host, config.port, config.options)

            MongoPersistenceEngine.new connection.db(config.database)
          end
          def self.build_with_proxy()
            ZmqPersistenceEngineProxy.new(build.init)
          end
        end
      end
    end
  end
end
