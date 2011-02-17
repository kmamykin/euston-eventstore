module EventStore
  module Persistence
    module Mongodb
      class MongoStreamHead
        def initialize(stream_id, head_revision, snapshot_revision)
          @stream_id = stream_id
          @head_revision = head_revision
          @snapshot_revision = snapshot_revision
        end

        attr_reader :stream_id, :head_revision, :snapshot_revision
      end
    end
  end
end