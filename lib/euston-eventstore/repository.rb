module Euston
  class Repository
    def initialize event_store, namespaces
      @event_store, @namespaces = event_store, namespaces
      @message_class_finder = MessageClassFinder.new @namespaces
    end

    def find event_source_id
      pair = event_store.get_snapshot_stream_pair id
      return nil if pair.snapshot.nil? && pair.stream.committed_events.empty?

      type = pair.snapshot.nil? ? pair.stream.committed_headers[:event_source_type] : pair.snapshot.headers[:event_source_type]
      event_stream = Euston::EventStream.new pair.stream.committed_headers[:source_message], pair.stream.committed_events
      snapshot = Euston::Snapshot.new type, pair.snapshot.headers[:version], pair.snapshot.payload
      history = EventSourceHistory.new event_stream, pair.snapshot
      type.new @message_class_finder, history
    end

    def save event_stream
      # stream = event_source.stream || @event_store.create_stream(aggregate.aggregate_id)
      # aggregate.uncommitted_events.each { |e| stream << EventStore::EventMessage.new(e.to_hash.stringify__keys) }
      # aggregate.uncommitted_commands.each { |c| stream << EventStore::CommandMessage.new(c.to_hash.stringify__keys) }
      # stream.uncommitted_headers[:aggregate_type] = aggregate.class.to_s
      # stream.commit_changes Euston.uuid.generate
    end
  end
end
