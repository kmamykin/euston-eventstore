module EventStore
  module Persistence
    module Mongodb
      module MongoCommitId
        def initialize(stream_id, commit_sequence)
          @stream_id = stream_id
          @commit_sequence = commit_sequence
        end

        attr_reader :stream_id, :commit_sequence
      end
    end
  end
end