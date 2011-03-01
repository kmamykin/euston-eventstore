require 'bson'

module EventStore
  module Serialization
    module Mongodb
      class MongoSerializer
        def self.serialize(graph)
          BSON.serialize :yaml => graph.to_yaml
        end

        def self.deserialize(input)
          YAML::load(BSON.deserialize(input)['yaml'])
        end
      end
    end
  end
end