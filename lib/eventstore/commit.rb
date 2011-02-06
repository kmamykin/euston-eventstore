module EventStore

  # Represents a series of events which have been fully committed as a single unit and which apply to the stream indicated.
  class Commit
    def initialize(stream_id, stream_revision, commit_id, commit_sequence, commit_timestamp, headers = OpenStruct.new, events = [])
      @stream_id = stream_id
      @stream_revision = stream_revision
      @commit_id = commit_id
      @commit_sequence = commit_sequence
      @commit_timestamp = commit_timestamp
      @headers = headers
      @events = events
    end

    # Gets the value which uniquely identifies the stream to which the commit belongs.
    attr_reader :stream_id

    # Gets the value which indicates the revision of the most recent event in the stream to which this commit applies.
    attr_reader :stream_revision

    # Gets the value which uniquely identifies the commit within the stream.
    attr_reader :commit_id

    # Gets the value which indicates the sequence (or position) in the stream to which this commit applies.
    attr_reader :commit_sequence
    
    # Gets the point in time at which the commit was persisted.
    attr_reader :commit_timestamp

    # Gets the metadata which provides additional, unstructured information about this commit.
    attr_reader :headers

    # Gets the collection of event messages to be committed as a single unit.
    attr_reader :events

    def ==(other)
      (other.is_a? Commit) && (@stream_id == other.stream_id) && (@commit_id == other.commit_id)
    end
  end

end