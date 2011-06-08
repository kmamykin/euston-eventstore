module EventStore

  # Represents a single element in a stream of events.
  class EventMessage

    def initialize(arg = nil)
      if arg.is_a?(Hash) && (arg.keys & ['body','headers']).size == 2
        @body, @headers = arg.values_at('body','headers')
      else
        @headers = {}
        @body = arg
      end
    end

    def to_hash
      {:headers=>@headers,:body=>@body}
    end

    # Gets the metadata which provides additional, unstructured information about this message.
    attr_reader :headers

    # Gets or sets the actual event message body.
    attr_reader :body
  end

end