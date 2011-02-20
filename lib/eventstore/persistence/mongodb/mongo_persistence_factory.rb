module EventStore
  module Persistence
    module Mongodb
      class MongoPersistenceFactory
        def self.build
          config = Mongodb::Config.instance
          connection = Mongo::Connection.new(config.host, config.port, config.options)
          
          MongoPersistenceEngine.new connection.db(config.database), EventStore::Serialization::Mongodb::MongoSerializer.new
        end
      end
    end
  end
end