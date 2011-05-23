require 'json'
require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'eventstore/commit'
require 'eventstore/errors'
require 'eventstore/event_message'
require 'eventstore/optimistic_event_store'
require 'eventstore/optimistic_event_stream'
require 'eventstore/snapshot'
require 'eventstore/dispatcher/asynchronous_dispatcher'
require 'eventstore/dispatcher/null_dispatcher'
require 'eventstore/dispatcher/synchronous_dispatcher'
require 'eventstore/persistence/stream_head'
require 'eventstore/persistence/mongodb/mongo_commit'
require 'eventstore/persistence/mongodb/mongo_commit_id'
require 'eventstore/persistence/mongodb/mongo_config'
require 'eventstore/persistence/mongodb/mongo_event_message'
require 'eventstore/persistence/mongodb/mongo_persistence_engine'
require 'eventstore/persistence/mongodb/mongo_persistence_factory'
require 'eventstore/persistence/mongodb/mongo_snapshot'
require 'eventstore/persistence/mongodb/mongo_stream_head'

module EventStore
  FIXNUM_MAX = (2**(0.size * 8 -2) -1)
end

class Hash
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_symbolize_keys}
    self
  end
end
