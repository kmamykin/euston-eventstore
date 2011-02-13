module EventStore
  class OptimisticEventStream
    def initialize(options)
      @persistence = options[:persistence]
      @committed_events = []
      @uncommitted_events = []
      @commit_sequence = 0

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

          raise StreamNotFoundError if committed_events.empty?
        end
      end
    end

    attr_reader :stream_id, :stream_revision, :commit_sequence, :committed_events, :uncommitted_events

    def <<(*events)
      events = events.flatten.reject { |e| e.nil? }
      raise ArgumentError.new('Expected a non-empty array of events to be passed to <<.') if events.empty?

      events.each do |event|
        event = EventMessage.new(event) unless event.is_a? EventMessage
        raise ArgumentError.new('Expected all events passed to << to have a populated body.') if event.body.nil?
        @uncommitted_events << event
      end
    end

    def commit_changes(commit_id, headers)
      return unless has_changes

      begin
        persist_changes commit_id, headers
      rescue ConcurrencyError => e
        commits = @persistence.get_from stream_id, stream_revision + 1, FIXNUM_MAX
        populate_stream stream_revision + 1, FIXNUM_MAX, commits

        raise e
      end
    end

    def clear_changes
      @uncommitted_events = []
    end
    
    protected

    def build_commit(commit_id, headers = OpenStruct.new)
      Commit.new({ :stream_id => stream_id,
                   :stream_revision => stream_revision + uncommitted_events.length,
                   :commit_id => commit_id,
                   :commit_sequence => commit_sequence + 1,
                   :headers => headers,
                   :events =>  @uncommitted_events })
    end

    def persist_changes(commit_id, headers)
      commit = build_commit commit_id, headers
      @persistence.commit commit

      populate_stream stream_revision + 1, commit.stream_revision, [ commit ]
      clear_changes
    end

    def has_changes
      !uncommitted_events.empty?
    end

    private

    def populate_stream(min_revision, max_revision, commits = [])
      commits.each do |commit|
        @commit_sequence = commit.commit_sequence
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