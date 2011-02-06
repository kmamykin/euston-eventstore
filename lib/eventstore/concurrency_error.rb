module EventStore
  # Represents an optimistic concurrency conflict between multiple writers.
  class ConcurrencyError < RuntimeError; end
end