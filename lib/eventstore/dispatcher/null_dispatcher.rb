module EventStore
  module Dispatcher
    class NullDispatcher
      def dispatch(commit)
        # no-op
      end
    end
  end
end