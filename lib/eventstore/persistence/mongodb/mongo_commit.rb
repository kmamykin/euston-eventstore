module EventStore
  module Persistence
    module Mongodb
      module MongoCommit
        extend ActiveSupport::Concern

        def to_hash
          {
            :id => { :stream_id => stream_id, :commit_sequence => commit_sequence },
            :starting_stream_revision => stream_revision - events.length - 1,
            :stream_revision => stream_revision,
            :commit_id => commit_id,
            :commit_timestamp => commit_timestamp,
            :headers => headers,
            :payload => BSON.serialize events
          }
        end

        def to_id_query
          { '_id' => { 'commit_sequence' => commit_sequence, 'stream_id' => stream_id } }
        end
      end
    end
  end

  class Commit
    include Persistence::Mongodb::MongoCommit
  end
end