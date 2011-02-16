require 'bson'

module EventStore
  module Serialization
    module Mongodb
      class MongoSerializer
        def serialize(graph)
          unless graph.is_a? Hash
            raise "Cannot serialize object of type #{graph.class} since it is not a Hash nor responds to to_hash" unless graph.respond_to? :to_hash
            graph = graph.to_hash
          end

          BSON.serialize graph
        end

        def deserialize(input)
          BSON.deserialize input
        end
      end
    end
  end
end