module Euston
  module EventStore
    module Persistence
      module Mongodb
        class MongoPersistenceEngine
          include MongoConcurrencyDetection

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

              persisted_snapshots.update id, doc, :upsert => true

              id = { '_id' => snapshot.stream_id }

              stream_head = MongoStreamHead.from_hash persisted_stream_heads.find_one(id)

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

              on_e11000_error = ->(e) do
                committed = persisted_commits.find_one(attempt.to_id_query)
                raise Euston::EventStore::DuplicateCommitError if !committed.nil? && committed['commit_id'] == attempt.commit_id
                raise Euston::EventStore::ConcurrencyError
              end

              on_other_error = ->(e) { raise EventStore::StorageError, e.message, e.backtrace }

              detect_mongo_concurrency :on_e11000_error => on_e11000_error, :on_other_error => on_other_error do
                persisted_commits.insert commit
                update_stream_head_async attempt.stream_id, attempt.stream_revision, attempt.events.length
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

              persisted_commits.find(query, :sort => order).to_a.map { |hash| MongoCommit.from_hash hash }
            end
          end

          def get_snapshot(stream_id, max_revision)
            try_mongo do
              query = { '_id' => {  '$gt' => { 'stream_id' => stream_id, 'stream_revision' => nil },
                                   '$lte' => { 'stream_id' => stream_id, 'stream_revision' => max_revision } } }
              order = [ '_id', Mongo::DESCENDING ]

              persisted_snapshots.find(query, :sort => order, :limit => 1).map { |hash| MongoSnapshot::from_hash hash }.first
            end
          end

          def get_streams_to_snapshot(max_threshold)
            try_mongo do
              query = { 'unsnapshotted' => { '$gte' => max_threshold } }
              order = [ 'unsnapshotted', Mongo::DESCENDING ]

              persisted_stream_heads.find(query, :sort => order).map { |hash| MongoStreamHead.from_hash hash }
            end
          end

          def get_undispatched_commits component_id = nil
            try_mongo do
              query = { 'dispatched' => false }
              query['component_id'] = component_id unless component_id.nil?

              order = [ 'commit_timestamp', Mongo::ASCENDING ]

              persisted_commits.find(query, :sort => order, :batch_size => 100).to_a.map { |hash| MongoCommit.from_hash hash }
            end
          end

          def init
            try_mongo do
              persisted_commits.ensure_index [ ['dispatched', Mongo::ASCENDING],
                                               ['component_id', Mongo::ASCENDING],
                                               ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

              persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
                                               ['events.stream_revision', Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

              persisted_commits.ensure_index [ ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'commit_timestamp_index'

              persisted_stream_heads.ensure_index [ ['unsnapshotted', Mongo::ASCENDING] ], :unique => false, :name => 'unsnapshotted_index'
            end
            self
          end

          def mark_commit_as_dispatched(commit)
            mark_commits_as_dispatched [commit]
          end

          def mark_commits_as_dispatched(commits)
            return if commits.empty?

            try_mongo do
              id_queries = commits.map { |c| c.to_id_query }
              query = { '$or' => id_queries }

              persisted_commits.update query, { '$set' => { 'dispatched' => true }, '$unset' => { 'component_id' => 1 } }, :multi => true
            end
          end

          def take_ownership_of_undispatched_commits component_id
            try_mongo do
              new_commits_eligible_for_dispatch  = { 'component_id' => nil,
                                                     'dispatched'   => false }

              commits_stuck_in_other_components  = { 'component_id'     => { '$ne'  => nil }                                       ,
                                                     'dispatched'       => false,
                                                     'commit_timestamp' => Time.now.to_f - 60 }

              query = { '$or'   => [ new_commits_eligible_for_dispatch, commits_stuck_in_other_components ] }
              doc   = { '$set'  => { 'component_id' => component_id } }

              persisted_commits.update query, doc, :multi => true
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
              id  = { '_id' => stream_id }
              doc = { '$set' => { 'head_revision' => stream_revision },
                      '$inc' => { 'snapshot_revision' => 0, 'unsnapshotted' => events_count } }

              persisted_stream_heads.update id, doc, :upsert => true
            end
          end

          CONCURRENCY_EXCEPTION = "E1100"
        end
      end
    end
  end
end
