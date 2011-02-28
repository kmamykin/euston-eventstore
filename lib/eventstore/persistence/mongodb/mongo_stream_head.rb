module EventStore
  module Persistence
    module Mongodb
      module MongoStreamHead
        extend ::ActiveSupport::Concern

        def to_hash
          {
            :stream_id => @stream_id,
            :head_revision => @head_revision,
            :snapshot_revision => @snapshot_revision
          }
        end
      end
    end

    class StreamHead
      include Mongodb::MongoStreamHead
    end
  end
end