module EventStore
  module Persistence
    module Mongodb
      class MongoPersistenceEngine
        def initialize(store, serializer)
          @store = store
          @serializer = serializer
        end

        def add_snapshot(snapshot)
          return false if snapshot.nil?

          begin
            mongo_snapshot = snapshot.to_hash
            persisted_snapshots.insert mongo_snapshot

            head = EventStore::Persistence::Mongodb::MongoStreamHead.new snapshot.stream_id, snapshot.stream_revision, snapshot.stream_revision
            save_stream_head_async head

            return true
          rescue Mongo::OperationFailure => e
            return false
          end
        end

        def commit(attempt)
          commit = attempt.to_hash

          begin
            # for concurrency / duplicate commit detection safe mode is required
            persisted_commits.insert commit, :safe => true
ap commit

            head = EventStore::Persistence::Mongodb::MongoStreamHead.new commit.id.stream_id, commit.stream_revision, 0
            save_stream_head_async head
          rescue Mongo::OperationFailure => e
            raise EventStore::StorageError.new(e.message, e) if e.message.include? CONCURRENCY_EXCEPTION

            committed = persisted_commits.find_one(commit.to_id_query)

            raise EventStore::DuplicateCommitError if committed.nil || committed[:commit_id] == commit.commit_id
            raise EventStore::ConcurrencyError
          end
        end

        def get_from(options)
          begin
            if options.has_key? :timestamp
              query = { 'commit_timestamp' => { '$gte' => options[:timestamp] } }
              order = { 'commit_timestamp' => 1 }
            else
              query = { '_id.stream_id' => options[:stream_id],
                        'stream_revision' => { '$gte' => options[:min_revision] },
                        'starting_stream_revision' => { '$lte' => options[:max_revision] } }

              order = { 'starting_stream_revision' => 1 }
            end

            persisted_commits.find(query)
                             .sort(order)
                             .to_a
                             .map { |c| EventStore::Commit.new c }
          rescue Exception => e
            raise EventStore::StorageError, e.to_s, e
          end
        end

        def get_snapshot(stream_id, max_revision)
          query = { '_id' => { '$gt' => { 'stream_id' => stream_id,
                                          'stream_revision' => nil },
                               '$lt' => { 'stream_id' => stream_id,
                                          'stream_revision' => max_revision } } }

          persisted_snapshots.find(query)
                             .sort({ '_id' => -1 })
                             .limit(1)
                             .to_a
                             .map { |c| EventStore::Commit.new c }
                             .first
        end

        def get_streams_to_snapshot(max_threshold)
          persisted_stream_heads.find({ '$where' => "this.head_revision >= this.snapshot_revision + #{max_threshold}" })
                                .to_a
                                .map { |c| EventStore::Commit.new c }
        end

        def get_undispatched_commits
          persisted_commits.find({ 'dispatched' => false })
                           .sort({ 'commit_stamp' => 1 })
                           .to_a
                           .map { |c| EventStore::Commit.new c }
        end

        def init
          persisted_commits.ensure_index [ ['dispatched', Mongo::ASCENDING],
                                           ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

          persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
                                           ['starting_stream_revision', Mongo::ASCENDING],
                                           ['stream_revision', Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

          persisted_commits.ensure_index [ ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'commit_timestamp_index'
        end

        def mark_commit_as_dispatched(commit)
          persisted_commits.update commit.to_id_query, { 'dispatched' => true }
        end

        private

        def persisted_commits
          @store.collection :commits
        end

        def persisted_snapshots
          @store.collection :snapshots
        end

        def persisted_stream_heads
          @store.collection :streams
        end

        def save_stream_head_async(head)
          query = { '_id' => head.stream_id }
          update = { 'head_revision' => head.head_revision,
                     'snapshot_revision' => head.snapshot_revision }

          persisted_stream_heads.update query, update, :upsert => true
        end

        CONCURRENCY_EXCEPTION = "E1100"
      end
    end
  end
end