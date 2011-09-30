module Euston
  module EventStore
    # A pair of snapshot & stream to reload an object in a performant way
    class SnapshotStreamPair
      def initialize snapshot, stream
        @snapshot = snapshot
        @stream   = stream
      end

      # A snapshot providing the state of the object up to the start of the stream
      attr_reader :snapshot

      # A stream of commits since the snapshot was taken
      attr_reader :stream
    end
  end
end
