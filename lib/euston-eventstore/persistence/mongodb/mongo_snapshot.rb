module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoSnapshot
          extend ::ActiveSupport::Concern

          class << self
            def from_hash(hash)
              return nil if hash.nil?

              id = hash['_id']

              Euston::EventStore::Snapshot.new id['stream_id'], id['stream_revision'], hash['payload']
            end
          end

          def to_hash
            {
              :_id => { :stream_id => stream_id, :stream_revision => stream_revision },
              :payload => payload.recursive_stringify_symbol_values!
            }
          end
        end
      end
    end

    class Snapshot
      include Persistence::Mongodb::MongoSnapshot
    end
  end
end
