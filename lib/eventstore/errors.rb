module EventStore
  # Represents an optimistic concurrency conflict between multiple writers.
  class ConcurrencyError < RuntimeError; end
    
  # Represents an attempt to commit the same information more than once.
  class DuplicateCommitError < RuntimeError; end
  
  # Represents a loss of communications with the storage
  class StorageUnavailableError < RuntimeError; end
  
  # Represents a general failure of the storage engine or persistence infrastructure.
  class StorageError < RuntimeError; end
  
  # Represents an attempt to commit the same information more than once.
  class StreamNotFoundError < RuntimeError; end
end
