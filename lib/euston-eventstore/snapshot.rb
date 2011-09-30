module Euston
  module EventStore
    # Represents a materialized view of a stream at specific revision.
    class Snapshot
      def initialize stream_id, stream_revision, payload, headers = nil
        @stream_id = stream_id
        @stream_revision = stream_revision
        @payload = payload
        @headers = headers
      end

      # Gets the value which uniquely identifies the stream to which the snapshot applies.
      attr_reader :stream_id

      # Gets the position at which the snapshot applies.
      attr_reader :stream_revision

      # Gets the snapshot or materialized view of the stream at the revision indicated.
      attr_reader :payload

      # Gets the metadata which provides additional, unstructured information about this snapshot.
      attr_reader :headers
    end
  end
end
