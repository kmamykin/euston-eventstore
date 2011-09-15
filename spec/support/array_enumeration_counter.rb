require 'delegate'

module Euston
  module EventStore
    class ArrayEnumerationCounter < DelegateClass(Array)
      def initialize(obj)
        super(obj)

        @invocations = 0
      end

      def each
        @invocations += 1
        super
      end

      attr_reader :invocations
    end
  end
end
