module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoCommandMessage
          extend ActiveSupport::Concern

          class << self
            def from_hash hash
              hash.recursive_symbolize_keys!

              message = CommandMessage.new hash[:body]
              message.instance_variable_set :@headers, hash[:headers]
              message
            end
          end

          def to_hash
            {
              :headers  => headers,
              :body     => body.to_hash.recursive_stringify_symbol_values!
            }
          end
        end
      end
    end

    class CommandMessage
      include Persistence::Mongodb::MongoCommandMessage
    end
  end
end
