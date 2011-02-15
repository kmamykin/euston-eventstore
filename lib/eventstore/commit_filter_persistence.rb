module EventStore

  class CommitFilterPersistence
    def initialize(inner, read_filters = [], write_filters = [])
      @inner = inner
      @read_filters = read_filters
      @write_filters = write_filters
    end

    def add_snapshot(snapshot)
      @inner.add_snapshot snapshot
    end

    def commit(attempt)
      @inner.commit filter_write(attempt)
    end

    def init
      @inner.init
    end

    def get_from(options)
      if options.has_key? :timestamp
        @inner.get_from options
      else
        @inner.get_from(options)
          .map { |x| filter_read x }
          .reject { |x| x.nil? }
          .to_a
      end
    end

    def get_undispatched_commits
      @inner.get_undispatched_commits
    end

    def mark_commit_as_dispatched(commit)
      @inner.mark_commit_as_dispatched commit
    end

    def get_snapshot(stream_id, max_revision)
      @inner.get_snapshot stream_id, max_revision
    end

    def get_streams_to_snapshot(max_threshold)
      @inner.get_streams_to_snapshot max_threshold
    end

    private

    def filter_read(persisted)
      @read_filters.each do |f|
        persisted = f.filter_read persisted
        break if persisted.nil?
      end

      persisted
    end

    def filter_write(attempt)
      @write_filters.each do |f|
        attempt = f.filter_write attempt
        break if attempt.nil?
      end

      attempt
    end
  end
end