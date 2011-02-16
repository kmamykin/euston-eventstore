module EventStore
  class SimpleMessage
    def initialize
      @contents = []
    end

    attr_accessor :id, :created, :value, :count
    attr_reader :contents

    def to_hash
      { :id => id,
        :created => created,
        :value => value,
        :count => count,
        :contents => contents }
    end
  end
end