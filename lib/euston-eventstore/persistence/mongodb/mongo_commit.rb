module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoCommit
          extend ::ActiveSupport::Concern

          included do
            alias_method :original_initialize, :initialize
            alias_method :initialize, :mongo_initialize
          end

          class << self
            def from_hash(hash)
              return nil if hash.nil?

              id = hash['_id']
              events = hash['events'].sort_by { |e| e["stream_revision"] }.to_a
              stream_revision = events.last['stream_revision']
              events = events.map { |e| Euston::EventStore::Persistence::Mongodb::MongoEventMessage.from_hash e['payload'] }

              Euston::EventStore::Commit.new :stream_id => id['stream_id'],
                                             :stream_revision => stream_revision,
                                             :commit_id => hash['commit_id'],
                                             :commit_sequence => id['commit_sequence'],
                                             :commit_timestamp => hash['commit_timestamp'],
                                             :headers => hash['headers'].recursive_symbolize_keys!,
                                             :events => events
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
              :commit_id => commit_id,
              :commit_timestamp => commit_timestamp.to_f,
              :dispatched => dispatched || false,
              :events => events.map { |e| e.to_hash },
              :headers => headers
            }
          end

          def to_mongo_commit
            mongo_stream_revision = stream_revision - (events.length - 1)
            mongo_events = events.map do |e|
              hash = { :stream_revision => mongo_stream_revision, :payload => e.to_hash }
              mongo_stream_revision += 1
              hash
            end

            {
              :_id => { :stream_id => stream_id, :commit_sequence => commit_sequence },
              :commit_id => commit_id,
              :commit_timestamp => commit_timestamp.to_f,
              :headers => headers,
              :events => mongo_events,
              :dispatched => false
            }
          end

          def to_id_query
            {
              '_id.commit_sequence' => commit_sequence,
              '_id.stream_id' => stream_id
            }
          end
        end
      end
    end

    class Commit
      include Persistence::Mongodb::MongoCommit
    end
  end
end
