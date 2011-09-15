module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoEventMessage
          extend ::ActiveSupport::Concern

          class << self
            def from_hash(hash)
              {}.recursive_symbolize_keys!
              message = EventMessage.new hash['body'].recursive_symbolize_keys!
              message.instance_variable_set :@headers, hash['headers'].recursive_symbolize_keys!
              message
            end
          end

          def to_hash
            {
              :headers => headers,
              :body => body.to_hash.recursive_stringify_symbol_values!
            }
          end
        end
      end
    end

    class EventMessage
      include Persistence::Mongodb::MongoEventMessage
    end
  end
end
