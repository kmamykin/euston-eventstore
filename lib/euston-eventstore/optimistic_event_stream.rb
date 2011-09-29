module Euston
  module EventStore
    class OptimisticEventStream
      def initialize(options)
        @persistence = options[:persistence]
        @committed_events = []
        @committed_headers = {}
        @uncommitted_events = []
        @uncommitted_headers = {}
        @commit_sequence = 0
        @identifiers = []

        if options.has_key? :snapshot
          snapshot = options[:snapshot]
          @stream_id = snapshot.stream_id
          commits = @persistence.get_from @stream_id, snapshot.stream_revision, options[:max_revision]
          populate_stream snapshot.stream_revision + 1, options[:max_revision], commits
          @stream_revision = snapshot.stream_revision + committed_events.length
        else
          @stream_id = options[:stream_id]
          @stream_revision = 0
          min_revision = options[:min_revision] ||= nil
          max_revision = options[:max_revision] ||= nil

          unless min_revision.nil? || max_revision.nil?
            commits = @persistence.get_from @stream_id, min_revision, max_revision
            populate_stream min_revision, max_revision, commits

            raise StreamNotFoundError if (min_revision > 0 && committed_events.empty?)
          end
        end
      end

      attr_reader :stream_id, :stream_revision, :commit_sequence, :committed_events, :committed_headers, :uncommitted_events, :uncommitted_headers

      def <<(event)
        @uncommitted_events << event unless event.nil? || event.body.nil?
      end

      def clear_changes
        @uncommitted_events = []
        @uncommitted_headers = {}
      end

      def commit_changes(commit_id)
        raise Euston::EventStore::DuplicateCommitError if @identifiers.include? commit_id

        return unless has_changes

        begin
          persist_changes commit_id
        rescue ConcurrencyError => e
          commits = @persistence.get_from stream_id, stream_revision + 1, FIXNUM_MAX
          populate_stream stream_revision + 1, FIXNUM_MAX, commits

          raise e
        end
      end

      protected

      def copy_values_to_new_commit(commit_id)
        Euston::EventStore::Commit.new :stream_id => stream_id,
                                       :stream_revision => stream_revision + uncommitted_events.length,
                                       :commit_id => commit_id,
                                       :commit_sequence => commit_sequence + 1,
                                       :commit_timestamp => Time.now.utc,
                                       :headers => uncommitted_headers,
                                       :events => uncommitted_events
      end

      def has_changes
        !uncommitted_events.empty?
      end

      def persist_changes(commit_id)
        commit = copy_values_to_new_commit commit_id
        @persistence.commit commit

        populate_stream stream_revision + 1, commit.stream_revision, [ commit ]
        clear_changes
      end

      def populate_stream(min_revision, max_revision, commits = [])
        commits.each do |commit|
          @identifiers << commit.commit_id
          @commit_sequence = commit.commit_sequence
          @committed_headers.merge! commit.headers || {}

          current_revision = commit.stream_revision - commit.events.length + 1

          return if current_revision > max_revision

          commit.events.each do |event|
            break if current_revision > max_revision

            unless current_revision < min_revision
              @committed_events << event
              @stream_revision = current_revision
            end

            current_revision += 1
          end
        end
      end
    end
  end
end
