module Euston
  module EventStore
    class OptimisticEventStore
      def initialize(persistence)
        @persistence = persistence
      end

      def instrumentation
        return nil unless @persistence.respond_to?(:instrumentation)
        @persistence.instrumentation
      end

      def add_snapshot(snapshot)
        @persistence.add_snapshot snapshot
      end

      def commit(attempt)
        return unless Commit.valid?(attempt) && !Commit.empty?(attempt)

        @persistence.commit attempt
      end

      def create_stream(stream_id)
        OptimisticEventStream.new(:stream_id => stream_id,
                                  :persistence => self)
      end

      def get_from(stream_id, min_revision, max_revision)
        @persistence.get_from(:stream_id => stream_id,
                              :min_revision => min_revision,
                              :max_revision => max_revision).to_enum
      end

      def get_snapshot(stream_id, max_revision)
        @persistence.get_snapshot stream_id, validate_max_revision(max_revision)
      end

      def get_streams_to_snapshot(max_threshold)
        @persistence.get_streams_to_snapshot max_threshold
      end

      def open_stream(options)
        options = { :stream_id => nil,
                    :min_revision => 0,
                    :max_revision => 0,
                    :snapshot => nil }.merge(options)

        options = options.merge(:max_revision => validate_max_revision(options[:max_revision]),
                                :persistence => self)

        if options[:snapshot].nil?
          options.delete :snapshot
        else
          options.delete :stream_id
          options.delete :min_revision
        end

        OptimisticEventStream.new options
      end

      private

      def validate_max_revision(max_revision)
        max_revision <= 0 ? FIXNUM_MAX : max_revision
      end
    end
  end
end
