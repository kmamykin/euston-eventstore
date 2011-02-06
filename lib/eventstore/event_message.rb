module EventStore

  # Represents a single element in a stream of events.
  class EventMessage
    def initialize(body = nil)
      @headers = OpenStruct.new
      @body = body
    end

    # Gets the metadata which provides additional, unstructured information about this message.
    attr_reader :headers

    # Gets or sets the actual event message body.
    attr_reader :body
  end
  
end