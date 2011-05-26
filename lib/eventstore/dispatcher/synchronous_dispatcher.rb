module EventStore
  module Dispatcher
    class SynchronousDispatcher
      def initialize persistence, &block
        @persistence = persistence
        @dispatch = block
      end

      def dispatch commit
        @dispatch.call commit
        @persistence.mark_commit_as_dispatched commit
      end

      def lookup
        @persistence.get_undispatched_commits.each { |commit| dispatch commit }
      end
    end
  end
end