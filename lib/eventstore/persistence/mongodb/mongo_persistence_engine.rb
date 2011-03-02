module EventStore
  module Persistence
    module Mongodb
      class MongoPersistenceEngine
        def initialize(store)
          @store = store
        end

        def add_snapshot(snapshot)
          return false if snapshot.nil?

          begin
            mongo_snapshot = snapshot.to_hash

            persisted_snapshots.insert mongo_snapshot
            persisted_stream_heads.update({ :_id => snapshot.stream_id },
                                          { :snapshot_revision => snapshot.stream_revision })

            return true
          rescue Mongo::OperationFailure
            return false
          end
        end

        def commit(attempt)
          commit = attempt.to_hash

          begin
            # for concurrency / duplicate commit detection safe mode is required
            persisted_commits.insert commit, :safe => true
            update_stream_head_async commit[:_id][:stream_id], commit[:stream_revision], commit[:_id][:commit_sequence] == 1
          rescue Mongo::OperationFailure => e
            raise(EventStore::StorageError, e.message, e.backtrace) unless e.message.include? CONCURRENCY_EXCEPTION

            committed = persisted_commits.find_one(attempt.to_id_query)

            raise EventStore::DuplicateCommitError if committed.nil? || committed['commit_id'] == commit[:commit_id]
            raise EventStore::ConcurrencyError
          end
        end

        def get_from(options)
          begin
            if options.has_key? :timestamp
              query = { :commit_timestamp => { '$gte' => options[:timestamp].to_f } }
              order = [ :commit_timestamp, Mongo::ASCENDING ]
            else
              query = { '_id.stream_id' => options[:stream_id],
                        :stream_revision => { '$gte' => options[:min_revision] },
                        :starting_stream_revision => { '$lte' => options[:max_revision] } }

              order = [ :starting_stream_revision, Mongo::ASCENDING ]
            end

            persisted_commits.find(query).sort(order).to_a.map { |commit| hash_to_mongo_commit commit }
          rescue Exception => e
            raise EventStore::StorageError, e.to_s, e.backtrace
          end
        end

        def get_snapshot(stream_id, max_revision)
          query = { :_id => { '$gt' => { :stream_id => stream_id,
                                         :stream_revision => nil },
                              '$lte' => { :stream_id => stream_id,
                                         :stream_revision => max_revision } } }

          persisted_snapshots.find(query)
                             .sort([ :_id, Mongo::DESCENDING ])
                             .limit(1)
                             .to_a
                             .map { |hash| hash_to_mongo_snapshot hash }
                             .first
        end

        def get_streams_to_snapshot(max_threshold)
          persisted_stream_heads.find({ '$where' => "this.head_revision >= this.snapshot_revision + #{max_threshold}" })
                                .to_a
                                .map { |hash| hash_to_mongo_stream_head hash }
        end

        def get_undispatched_commits
          persisted_commits.find({ :dispatched => false })
                           .sort([ :commit_timestamp, Mongo::ASCENDING ])
                           .to_a
                           .map { |hash| hash_to_mongo_commit hash }
        end

        def init
          persisted_commits.ensure_index [ [:dispatched, Mongo::ASCENDING],
                                           [:commit_timestamp, Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

          persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
                                           [:starting_stream_revision, Mongo::ASCENDING],
                                           [:stream_revision, Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

          persisted_commits.ensure_index [ [:commit_timestamp, Mongo::ASCENDING] ], :unique => false, :name => 'commit_timestamp_index'
        end

        def mark_commit_as_dispatched(commit)
          persisted_commits.update commit.to_id_query, { :dispatched => true }
        end

        private

        def hash_to_mongo_commit(hash)
          hash = ::ActiveSupport::HashWithIndifferentAccess.new hash
          hash[:_id] = ::ActiveSupport::HashWithIndifferentAccess.new hash[:_id]
          hash[:commit_timestamp] = Time.at hash[:commit_timestamp]
          hash.delete :friendly_timestamp
          hash[:headers] = ::ActiveSupport::HashWithIndifferentAccess.new hash[:headers]
          hash[:payload] = hash[:payload].map { |p| ::ActiveSupport::HashWithIndifferentAccess.new p }

          EventStore::Commit.from_hash hash
        end

        def hash_to_mongo_snapshot(hash)
          EventStore::Snapshot.new hash['_id']['stream_id'], hash['_id']['stream_revision'], YAML::load(hash['payload'])
        end

        def hash_to_mongo_stream_head(hash)
          EventStore::Persistence::StreamHead.new hash['stream_id'], hash['head_revision'], hash['snapshot_revision']
        end

        def persisted_commits
          @store.collection :commits
        end

        def persisted_snapshots
          @store.collection :snapshots
        end

        def persisted_stream_heads
          @store.collection :streams
        end

        def update_stream_head_async(stream_id, stream_revision, first_commit)
          Thread.fork do
            if first_commit
              head = EventStore::Persistence::StreamHead.new stream_id, stream_revision, 0
              persisted_stream_heads.insert head.to_hash
            else
              persisted_stream_heads.update({ :_id => stream_id }, { :head_revision => stream_revision })
            end
          end
        end

        CONCURRENCY_EXCEPTION = "E1100"
      end
    end
  end
end