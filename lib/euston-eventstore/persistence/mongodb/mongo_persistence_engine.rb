module Euston
  module EventStore
    module Persistence
      module Mongodb
        class MongoPersistenceEngine
          def initialize(store)
            @store = store

            collection_names = store.collection_names
            store.create_collection 'commits'   unless collection_names.include? 'commits'
            store.create_collection 'snapshots' unless collection_names.include? 'snapshots'
            store.create_collection 'streams'   unless collection_names.include? 'streams'
          end

          def add_snapshot(snapshot)
            return false if snapshot.nil?

            begin
              mongo_snapshot = snapshot.is_a?(Hash) ? snapshot : snapshot.to_hash

              id  = { '_id'     => mongo_snapshot[:_id] }
              doc = { 'headers' => mongo_snapshot[:headers],
                      'payload' => mongo_snapshot[:payload] }.merge(id)

              persisted_snapshots.update id, doc, { :upsert => true }

              id = { '_id' => snapshot.stream_id }

              # jmongo's find_one is broken
              if defined?(JMongo)
                stream_head = MongoStreamHead.from_hash persisted_stream_heads.find(id).to_a.first
              else
                stream_head = MongoStreamHead.from_hash persisted_stream_heads.find_one(id)
              end

              modifiers = { '$set' => { 'snapshot_revision' => snapshot.stream_revision,
                                        'unsnapshotted'     => stream_head.head_revision - snapshot.stream_revision } }

              persisted_stream_heads.update id, modifiers
              return true
            rescue Mongo::OperationFailure
              return false
            end
          end

          def commit(attempt)
            try_mongo do
              commit = attempt.to_mongo_commit

              begin
                # for concurrency / duplicate commit detection safe mode is required
                persisted_commits.insert commit, :safe => true
                update_stream_head_async attempt.stream_id, attempt.stream_revision, attempt.events.length
              rescue Mongo::OperationFailure, NativeException => e
                raise(Euston::EventStore::StorageError, e.message, e.backtrace) unless e.message.include? CONCURRENCY_EXCEPTION

                # jmongo's find_one is broken
                if defined?(JMongo)
                  committed = persisted_commits.find(attempt.to_id_query).to_a.first
                else
                  committed = persisted_commits.find_one(attempt.to_id_query)
                end

                raise Euston::EventStore::DuplicateCommitError if !committed.nil? && committed['commit_id'] == attempt.commit_id
                raise Euston::EventStore::ConcurrencyError
              end
            end
          end

          def get_from(options)
            try_mongo do
              if options.has_key? :timestamp
                query = { 'commit_timestamp' => { '$gte' => options[:timestamp].to_f } }
                order = [ 'commit_timestamp', Mongo::ASCENDING ]
              else
                query = { '_id.stream_id' => options[:stream_id],
                          'events.stream_revision' => { '$gte' => options[:min_revision], '$lte' => options[:max_revision] } }

                order = [ 'events.stream_revision', Mongo::ASCENDING ]
              end

              persisted_commits.find(query).sort(order).to_a.map { |hash| MongoCommit.from_hash hash }
            end
          end

          def get_snapshot(stream_id, max_revision)
            try_mongo do
              query = { '_id' => {  '$gt' => { 'stream_id' => stream_id, 'stream_revision' => nil },
                                   '$lte' => { 'stream_id' => stream_id, 'stream_revision' => max_revision } } }
              order = [ '_id', Mongo::DESCENDING ]

              persisted_snapshots.find(query).sort(order).limit(1).to_a.map { |hash| MongoSnapshot::from_hash hash }.first
            end
          end

          def get_streams_to_snapshot(max_threshold)
            try_mongo do
              query = { 'unsnapshotted' => { '$gte' => max_threshold } }
              order = [ 'unsnapshotted', Mongo::DESCENDING ]

              persisted_stream_heads.find(query).sort(order).to_a.map { |hash| MongoStreamHead.from_hash hash }
            end
          end

          def get_undispatched_commits
            try_mongo do
              query = { 'dispatched' => false }
              order = [ 'commit_timestamp', Mongo::ASCENDING ]

              persisted_commits.find(query).sort(order).to_a.map { |hash| MongoCommit.from_hash hash }
            end
          end

          def init
            try_mongo do
              persisted_commits.ensure_index [ ['dispatched', Mongo::ASCENDING],
                                               ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

              persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
                                               ['events.stream_revision', Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

              persisted_commits.ensure_index [ ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'commit_timestamp_index'

              persisted_stream_heads.ensure_index [ ['unsnapshotted', Mongo::ASCENDING] ], :unique => false, :name => 'unsnapshotted_index'
            end
            self
          end

          def mark_commit_as_dispatched(commit)
            try_mongo do
              persisted_commits.update commit.to_id_query, { '$set' => { 'dispatched' => true }}
            end
          end

          private

          def persisted_commits
            @store.collection 'commits'
          end

          def persisted_snapshots
            @store.collection 'snapshots'
          end

          def persisted_stream_heads
            @store.collection 'streams'
          end

          def try_mongo(&block)
            begin
              yield block
            rescue Mongo::ConnectionError => e
              raise Euston::EventStore::StorageUnavailableError, e.to_s, e.backtrace
            rescue Mongo::MongoDBError => e
              raise Euston::EventStore::StorageError, e.to_s, e.backtrace
            end
          end

          def update_stream_head_async(stream_id, stream_revision, events_count)
            Thread.fork do
              persisted_stream_heads.update(
                { '_id' => stream_id },
                { '$set' => { 'head_revision' => stream_revision }, '$inc' => { 'snapshot_revision' => 0, 'unsnapshotted' => events_count } },
                { :upsert  => true })
            end
          end

          CONCURRENCY_EXCEPTION = "E1100"
        end
      end
    end
  end
end
