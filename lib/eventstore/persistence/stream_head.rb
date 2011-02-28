module EventStore
  module Persistence
    # Indicates the most recent information representing the head of a given stream.
    class StreamHead
      def initialize(stream_id, head_revision, snapshot_revision)
        @stream_id = stream_id
        @head_revision = head_revision
        @snapshot_revision = snapshot_revision
      end

      # Gets the value which uniquely identifies the stream where the last snapshot exceeds the allowed threshold.
      attr_reader :stream_id

      # Gets the value which indicates the revision, length, or number of events committed to the stream.
      attr_reader :head_revision

      # Gets the value which indicates the revision at which the last snapshot was taken.
      attr_reader :snapshot_revision
    end
  end
end