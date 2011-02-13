require 'thread'

module EventStore
  # Tracks the commits for a set of streams to determine if a particular commit has already
	# been committed thus relaxing the requirements upon the persistence engine as well as
	# reducing latency by avoiding needless database roundtrips through keeping the values which
	# uniquely identify each commit in memory.
	# For storage engines with relaxed consistency guarantees, such as a document database,
	# the CommitTracker prevents the need to query the persistence engine prior to a commit.
	# For storage engines with stronger consistency guarantees, such as a relational database,
	# the CommitTracker helps to avoid the increased latency incurred from extra roundtrips.
  class CommitTracker
    MAX_COMMITS_TRACKED_PER_STREAM = 1000
    
    def initialize(commits_to_track_per_stream = MAX_COMMITS_TRACKED_PER_STREAM)
      @commits_to_track_per_stream = commits_to_track_per_stream
      @streams = Hash.new
      @mutex = Mutex.new
    end

    def contains?(attempt)
      stream = get_stream attempt.stream_id
      stream != nil && stream.contains?(attempt.commit_id)
    end

    def get_stream(stream_id)
      @mutex.synchronize do
        @streams.has_key?(stream_id.to_s) ? @streams[stream_id.to_s] : nil
      end
    end

    def get_stream_head(stream_id)
      stream = get_stream stream_id
      stream.nil? ? nil : stream.head
    end

    def track(committed)
      stream = nil

      @mutex.synchronize do
        stream = @streams[committed.stream_id.to_s] ||= TrackedStream.new(@commits_to_track_per_stream)
      end

      stream.track committed
    end

    class TrackedStream
      def initialize(commits_to_track)
        @commits_to_track = commits_to_track
        @lookup = Set.new
        @ordered = []
        @mutex = Mutex.new
      end

      attr_reader :head

      def contains?(commit_id)
        @lookup.include? commit_id
      end
      
      def track(committed)
        return if @lookup.include?(committed.commit_id)

        @mutex.synchronize do
          return if @lookup.include?(committed.commit_id)

          @head = committed if @head.nil? || committed.commit_sequence == @head.commit_sequence + 1
          @lookup.add committed.commit_id
          @ordered << committed.commit_id

          return if @ordered.length <= @commits_to_track

          @lookup.delete @ordered.shift
        end
      end
    end
  end
end