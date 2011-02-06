module EventStore
  # Represents an attempt to commit the same information more than once.
  class StreamNotFoundError < RuntimeError; end
end