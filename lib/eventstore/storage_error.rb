module EventStore
  # Represents a general failure of the storage engine or persistence infrastructure.
  class StorageError < RuntimeError; end
end