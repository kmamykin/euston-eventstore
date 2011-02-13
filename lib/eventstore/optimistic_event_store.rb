module EventStore
  class OptimisticEventStore
    def initialize(persistence, dispatcher)
      @persistence = persistence
      @dispatcher = dispatcher
      @tracker = CommitTracker.new
    end

    def add_snapshot(snapshot)
      @persistence.add_snapshot snapshot
    end

    def commit(attempt)
      return unless attempt.valid? && !attempt.empty?

      throw_on_duplicate_or_concurrent_writes attempt
      persist_and_dispatch attempt
    end

    def create_stream(stream_id)
      OptimisticEventStream.new(:stream_id => stream_id,
                                :persistence => self)
    end
    
    def get_from(stream_id, min_revision, max_revision)
      @persistence.get_from(stream_id, min_revision, max_revision).to_enum.map do |commit|
        @tracker.track commit
        commit
      end
    end

    def get_snapshot(stream_id, max_revision)
      @persistence.get_snapshot stream_id, max_revision
    end

    def open_stream(stream_id, min_revision, max_revision)
      stream = OptimisticEventStream.new(:stream_id => stream_id,
                                         :persistence => self,
                                         :min_revision => min_revision,
                                         :max_revision => validate_max_revision(max_revision))
      stream.commit_sequence == 0 ? nil : stream
    end

    def open_stream_from_snapshot(snapshot, max_revision)
      OptimisticEventStream.new(:snapshot => snapshot,
                                :persistence => self,
                                :max_revision => validate_max_revision(max_revision))
    end

    protected

    def persist_and_dispatch(attempt)
      @persistence.commit attempt
			@tracker.track attempt
			@dispatcher.dispatch attempt
    end

    def throw_on_duplicate_or_concurrent_writes(attempt)
      raise DuplicateCommitError if @tracker.contains? attempt

      head = @tracker.get_stream_head attempt.stream_id
      return if head.nil?
      
      raise ConcurrencyError if head.commit_sequence >= attempt.commit_sequence
      raise ConcurrencyError if head.stream_revision >= attempt.stream_revision
      raise StorageError if head.commit_sequence < attempt.commit_sequence - 1
      raise StorageError if head.stream_revision < attempt.stream_revision - attempt.events.length
    end

    private

    def validate_max_revision(max_revision)
      max_revision <= 0 ? FIXNUM_MAX : max_revision
    end
  end
end