module EventStore
  module Persistence
    module Mongodb
      module MongoSnapshot
        extend ::ActiveSupport::Concern

        def to_hash
          {
            :id => { :stream_id => stream_id, :stream_revision => stream_revision },
            :payload => payload.to_hash
          }
        end
      end
    end
  end

  class Snapshot
    include Persistence::Mongodb::MongoSnapshot
  end
end