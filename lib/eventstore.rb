require 'eventstore/commit'
require 'eventstore/concurrency_error'
require 'eventstore/duplicate_commit_error'
require 'eventstore/event_message'
require 'eventstore/optimistic_event_store'
require 'eventstore/optimistic_event_stream'
require 'eventstore/snapshot'
require 'eventstore/storage_error'
require 'eventstore/stream_not_found_error'
require 'eventstore/dispatcher/asynchronous_dispatcher'
require 'eventstore/dispatcher/synchronous_dispatcher'
require 'eventstore/persistence/commit_filter_persistence'
require 'eventstore/persistence/commit_tracker'
require 'eventstore/persistence/mongodb/mongo_commit'
require 'eventstore/persistence/mongodb/mongo_commit_id'
require 'eventstore/persistence/mongodb/mongo_persistence_engine'
require 'eventstore/persistence/mongodb/mongo_stream_head'
require 'eventstore/serialization/mongodb/mongo_serializer'

module EventStore
  FIXNUM_MAX = (2**(0.size * 8 -2) -1)
end