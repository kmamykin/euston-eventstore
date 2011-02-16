module EventStore
  module Dispatcher
    class SynchronousDispatcher
      def initialize(bus, persistence)
        @bus = bus
        @persistence = persistence

        start
      end

      def dispatch(commit)
        @bus.publish commit
        @persistence.mark_commit_as_dispatched commit
      end

      private

      def start
        @persistence.init
        @persistence.get_undispatched_commits.each { |commit| dispatch commit }
      end
    end
  end
end