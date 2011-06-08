module EventStore
  module Persistence
    module Mongodb
      class ZmqPersistenceEngineProxy
        def initialize(engine)
          @engine = engine
          @engine.init
        end

        def add_snapshot(snapshot)
          ret = @engine.add_snapshot(snapshot)
          {:code='200',:status=>ret.to_s}
        end

        def commit(attempt) # attempt will be a hash; function returns nil
          commit_attempt = EventStore::Commit.new(attempt)
          try_mongo do
            @engine.commit(commit_attempt)
          end
        end

        def get_from(options)
          try_mongo do
            @engine.get_from(options)
          end
        end

        def get_snapshot(options)
          try_mongo do
            @engine.get_snapshotget(options.values_at(:stream_id,:max_revision))
          end
        end

        def get_streams_to_snapshot(options)
          try_mongo do
            @engine.get_snapshotget_from(options[:max_threshold])
          end
        end

        private

        def try_mongo
          code,status,data = '200',nil,nil
          begin
            data = yield
            status = 'success'
          rescue EventStore::StorageError => e
            code, status, data = '503', e.message, e.backtrace
          rescue EventStore::DuplicateCommitError => e
            code = '409'
          rescue raise EventStore::ConcurrencyError
            code = '423'
          end
          {:code=>code,:status=>status,:data=>data}
      end
    end
  end
end