require 'json'
require 'active_support'
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

Json = JSON if defined?(JSON) && !defined?(Json)

module HashExt
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    dup.stringify_keys!
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+.
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  def recursive_stringify_keys!
    stringify_keys!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_stringify_keys!}
    self
  end

  def recursive_symbolize_keys!
    symbolize_keys!
    values.select{|v| v.is_a? Hash}.each{|h| h.recursive_symbolize_keys!}
    self
  end
end

class Hash
  include HashExt
end

module JMongo
  module BasicDBObjectExtentions
    include HashExt
  end
end

