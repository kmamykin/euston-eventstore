module Euston
  module EventStore
    # Represents a materialized view of a stream at specific revision.
    class Snapshot
      def initialize(stream_id, stream_revision, payload)
        @stream_id = stream_id
        @stream_revision = stream_revision
        @payload = payload
      end

      # Gets the value which uniquely identifies the stream to which the snapshot applies.
      attr_reader :stream_id

      # Gets the position at which the snapshot applies.
      attr_reader :stream_revision

      # Gets the snapshot or materialized view of the stream at the revision indicated.
      attr_reader :payload
    end
  end
end