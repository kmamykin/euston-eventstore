module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoCommit
          extend ActiveSupport::Concern

          included do
            alias_method :original_initialize, :initialize
            alias_method :initialize, :mongo_initialize
            alias_method :original_to_hash, :to_hash
            alias_method :to_hash, :to_mongo_hash
          end

          class << self
            def from_hash(hash)
              return nil if hash.nil?

              id = hash['_id']
              events = hash['events'].sort_by { |e| e["stream_revision"] }.to_a
              commands = hash['commands']
              stream_revision = events.last['stream_revision']
              events = events.map { |e| MongoEventMessage.from_hash e['payload'] }
              commands = commands.map { |c| MongoCommandMessage.from_hash c['payload'] }

              Euston::EventStore::Commit.new :stream_id => id['stream_id'],
                                             :stream_revision => stream_revision,
                                             :commit_id => hash['commit_id'],
                                             :commit_sequence => id['commit_sequence'],
                                             :commit_timestamp => hash['commit_timestamp'],
                                             :headers => hash['headers'].recursive_symbolize_keys!,
                                             :events => events,
                                             :commands => commands
            end
          end

          def mongo_initialize(hash)
            original_initialize(hash)
            @dispatched = hash[:dispatched]
          end

          attr_reader :dispatched

          def to_mongo_hash
            hash = original_to_hash
            hash[:_id] = { :stream_id => hash.delete(:stream_id), :commit_sequence => hash.delete(:commit_sequence) }
            hash.delete :stream_revision
            hash.delete :commit_sequence
            hash[:dispatched] ||= false
            hash[:events] = hash[:events].map { |e| e.to_hash }
            hash[:commands] = hash[:commands].map { |c| c.to_hash }
            hash[:commit_timestamp] = hash[:commit_timestamp].to_f
            hash
          end

          def to_mongo_commit
            mongo_stream_revision = stream_revision - (events.length - 1)

            hash = to_mongo_hash

            hash[:events] = events.map do |e|
              event_hash = { :stream_revision => mongo_stream_revision, :payload => e.to_hash }
              mongo_stream_revision += 1
              event_hash
            end

            hash[:commands] = commands.map do |c|
              c.to_hash
            end

            hash[:commit_timestamp_for_humans] = Time.at(hash[:commit_timestamp]).utc

            hash
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
