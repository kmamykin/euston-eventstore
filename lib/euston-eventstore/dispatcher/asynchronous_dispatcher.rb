module Euston
  module EventStore
    module Dispatcher
      class AsynchronousDispatcher
        def initialize(bus, persistence, &block)
          @bus = bus
          @persistence = persistence
          @handle_exception = block_given? ? block : Proc.new {}

          start
        end

        def dispatch(commit)
          Thread.fork(commit) { |c| begin_dispatch c }
        end

        protected

        def begin_dispatch(commit)
          begin
            @bus.publish commit
            @persistence.mark_commit_as_dispatched commit
          rescue Exception => e
            @handle_exception.call commit, e
          end
        end

        private

        def start
          @persistence.init
          @persistence.get_undispatched_commits.each { |commit| dispatch commit }
        end
      end
    end
  end
end
