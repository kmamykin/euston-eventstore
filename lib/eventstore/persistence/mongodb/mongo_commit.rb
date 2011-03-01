module EventStore
  module Persistence
    module Mongodb
      module MongoCommit
        extend ::ActiveSupport::Concern

        included do
          alias_method :original_initialize, :initialize
          alias_method :initialize, :mongo_initialize
        end

        module ClassMethods
          def from_hash(hash)
            EventStore::Commit.new :stream_id => hash[:_id][:stream_id],
                                   :stream_revision => hash[:stream_revision],
                                   :commit_id => hash[:commit_id],
                                   :commit_sequence => hash[:_id][:commit_sequence],
                                   :commit_timestamp => hash[:commit_timestamp],
                                   :headers => hash[:headers],
                                   :events => hash[:payload]
          end
        end

        def mongo_initialize(hash)
          original_initialize(hash)
          @dispatched = hash[:dispatched]
        end

        attr_reader :dispatched

        def to_hash
          {
            :_id => { :stream_id => stream_id, :commit_sequence => commit_sequence },
            :starting_stream_revision => stream_revision - (events.length - 1),
            :stream_revision => stream_revision,
            :commit_id => commit_id,
            :commit_timestamp => commit_timestamp.to_f,
            :friendly_commit_timestamp => commit_timestamp.utc.strftime('%d-%b-%Y %H:%M:%S.%N'),
            :dispatched => dispatched || false,
            :headers => headers,
            :payload => events.map { |e| e.to_hash }
          }
        end

        def to_id_query
          { '_id.commit_sequence' => commit_sequence, '_id.stream_id' => stream_id }
        end
      end
    end
  end

  class Commit
    include Persistence::Mongodb::MongoCommit
  end
end