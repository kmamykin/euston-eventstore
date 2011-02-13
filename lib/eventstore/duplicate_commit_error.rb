module EventStore
  # Represents an attempt to commit the same information more than once.
  class DuplicateCommitError < RuntimeError; end
end