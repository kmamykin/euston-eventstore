module Euston
  module Repository
    class << self
      def find type, id
        pair = event_store.get_snapshot_stream_pair id
        return nil if pair.snapshot.nil? && pair.stream.committed_events.empty?

        type.hydrate pair.stream, pair.snapshot
      end

      def save aggregate
        stream = aggregate.stream
        aggregate.uncommitted_events.each { |e| stream << EventStore::Persistence::Mongodb::MongoEventMessage.new(e.to_hash.stringify__keys) }
        aggregate.uncommitted_commands.each { |c| stream << EventStore::Persistence::Mongodb::MongoCommandMessage.new(c.to_hash.stringify__keys) }
        stream.uncommitted_headers[:aggregate_type] = aggregate.class.to_s
        stream.commit_changes Euston.uuid.generate
      end
    end
  end
end
