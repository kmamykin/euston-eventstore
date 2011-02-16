module EventStore
  module Persistence
    module Mongodb
      class MongoPersistenceEngine
        def initialize(store, serializer)
          @store = store
          @serializer = serializer
        end

        def init
          persisted_commits.ensure_index [ ['dispatched', Mongo::ASCENDING],
                                           ['commit_stamp', Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

          persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
                                           ['starting_stream_revision', Mongo::ASCENDING],
                                           ['stream_revision', Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

          persisted_commits.ensure_index [ ['commit_stamp', Mongo::ASCENDING] ], :unique => false, :name => 'commit_stamp_index'
        end

        def get_from(options)
          begin
            if options.has_key? :timestamp
              query = { 'commit_stamp' => { '$gte' => options[:timestamp] } }
              order = { 'commit_stamp' => 1 }
            else
              query = { '_id.stream_id' => options[:stream_id],
                        'stream_revision' => { '$gte' => options[:min_revision] },
                        'starting_stream_revision' => { '$lte' => options[:max_revision] } }

              order = { 'starting_stream_revision' => 1 }
            end

            persisted_commits.find(query)
                             .sort(order)
                             .to_a
                             .map { |d| @serializer.deserialize d }
          rescue Exception => e
            raise EventStore::StorageError, e.to_s, e
          end
        end

        private

        def persisted_commits
          @store.get_collection :commits
        end

        def persisted_snapshots
          @store.get_collection :snapshots
        end

        def persisted_stream_heads
          @store.get_collection :streams
        end

        CONCURRENCY_EXCEPTION = "E1100"
      end
    end
  end
end

__END__

		public virtual void Commit(Commit attempt)
		{
			var commit = attempt.ToMongoCommit(this.serializer);

			try
			{
				// for concurrency / duplicate commit detection safe mode is required
				this.PersistedCommits.Insert(commit, SafeMode.True);

				var head = new MongoStreamHead(commit.Id.StreamId, commit.StreamRevision, 0);
				this.SaveStreamHeadAsync(head);
			}
			catch (MongoException e)
			{
				if (!e.Message.Contains(ConcurrencyException))
					throw new StorageException(e.Message, e);

				var committed = this.PersistedCommits.FindOne(commit.ToMongoCommitIdQuery());
				if (committed == null || committed.CommitId == commit.CommitId)
					throw new DuplicateCommitException();

				throw new ConcurrencyException();
			}
		}

		public virtual IEnumerable<Commit> GetUndispatchedCommits()
		{
			var query = Query.EQ("Dispatched", false);

			return this.PersistedCommits
				.Find(query)
				.SetSortOrder("CommitStamp")
				.Select(mc => mc.ToCommit(this.serializer));
		}
		public virtual void MarkCommitAsDispatched(Commit commit)
		{
			var query = commit.ToMongoCommitIdQuery();
			var update = Update.Set("Dispatched", true);
			this.PersistedCommits.Update(query, update);
		}

		public virtual IEnumerable<StreamHead> GetStreamsToSnapshot(int maxThreshold)
		{
			var query = Query
				.Where(BsonJavaScript.Create("this.HeadRevision >= this.SnapshotRevision + " + maxThreshold));

			return this.PersistedStreamHeads
				.Find(query)
				.ToArray()
				.Select(x => x.ToStreamHead());
		}
		public virtual Snapshot GetSnapshot(Guid streamId, int maxRevision)
		{
			return this.PersistedSnapshots
				.Find(streamId.ToSnapshotQuery(maxRevision))
				.SetSortOrder(SortBy.Descending("_id"))
				.SetLimit(1)
				.Select(mc => mc.ToSnapshot(this.serializer))
				.FirstOrDefault();
		}

		public virtual bool AddSnapshot(Snapshot snapshot)
		{
			if (snapshot == null)
				return false;

			try
			{
				var mongoSnapshot = snapshot.ToMongoSnapshot(this.serializer);
				this.PersistedSnapshots.Insert(mongoSnapshot);

				var head = new MongoStreamHead(snapshot.StreamId, snapshot.StreamRevision, snapshot.StreamRevision);
				this.SaveStreamHeadAsync(head);

				return true;
			}
			catch (MongoException)
			{
				return false;
			}
		}

		private void SaveStreamHeadAsync(MongoStreamHead streamHead)
		{
			// ThreadPool.QueueUserWorkItem(item => this.PersistedStreamHeads.Save(item as StreamHead), streamHead);
			var query = Query.EQ("_id", streamHead.StreamId);
			var update = Update
				.Set("HeadRevision", streamHead.HeadRevision)
				.Set("SnapshotRevision", streamHead.SnapshotRevision);

			this.PersistedStreamHeads.Update(query, update, UpdateFlags.Upsert);
		}
	}