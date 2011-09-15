module Euston
  module EventStore

    # Represents a series of events which have been fully committed as a single unit and which apply to the stream indicated.
    class Commit
      def initialize(hash)
        defaults = {
          :stream_id => nil,
          :stream_revision => 1,
          :commit_id => nil,
          :commit_sequence => 1,
          :commit_timestamp => Time.now.utc,
          :headers => OpenStruct.new,
          :events => []
        }
        values = defaults.merge hash
        defaults.keys.each { |key| instance_variable_set "@#{key}", values[key] }
      end

      def to_hash
        {
          :stream_id => stream_id,
          :stream_revision => stream_revision,
          :commit_id => commit_id,
          :commit_sequence => commit_sequence,
          :commit_timestamp => commit_timestamp,
          :headers => headers.is_a?(OpenStruct) ? headers.instance_variable_get(:@table) : headers,
          :events => events
        }
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

      class << self
        def empty?(attempt)
          attempt.nil? || attempt.events.empty?
        end

        def has_identifier?(attempt)
          !(attempt.stream_id.nil? || attempt.commit_id.nil?)
        end

        def valid?(attempt)
          raise ArgumentError.new('The commit must not be nil.') if attempt.nil?
          raise ArgumentError.new('The commit must be uniquely identified.') unless Commit.has_identifier? attempt
          raise ArgumentError.new('The commit sequence must be a positive number.') unless attempt.commit_sequence > 0
          raise ArgumentError.new('The stream revision must be a positive number.') unless attempt.stream_revision > 0
          raise ArgumentError.new('The stream revision must always be greater than or equal to the commit sequence.') if (attempt.stream_revision < attempt.commit_sequence)

          true
        end
      end
    end
  end
end
