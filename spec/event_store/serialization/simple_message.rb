module Euston
  module EventStore
    class SimpleMessage
      def initialize
        @contents = []
      end

      attr_accessor :id, :created, :value, :count
      attr_reader :contents
    end
  end
end