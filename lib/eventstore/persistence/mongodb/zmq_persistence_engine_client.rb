module EventStore
  module Persistence
    module Mongodb
      class ZmqPersistenceEngineClient
        def initialize(zmq_client)
          @zmq_client = zmq_client
        end

        def add_snapshot(snapshot)
          return false if snapshot.nil?
          ret = false
          begin
            request = JSON.generate(snapshot.to_hash)
            reply = try_zmq do
              @zmq_client.send('add_snapshot',request) #is a hash of code, status, data
            end
            status,data = process_reply(reply)
            ret = status == 'true'
          rescue => e
            #
          end
          ret
        end

        def commit(attempt) #is a EventStore::Commit, return nil
          request = JSON.generate(attempt.to_hash)
          reply = try_zmq do
            @zmq_client.send('commit',request) #is a hash of code, status, data
          end
          process_reply(reply)
        end

        def get_from(options)
          request = JSON.generate(options)
          reply = try_zmq do
            @zmq_client.send('get_from',request) #is a hash of code, status, data
          end
          status,data = process_reply(reply)
          data
        end

        def get_snapshot(stream_id, max_revision)
          request = JSON.generate({'stream_id'=>stream_id,'max_revision'=>max_revision})
          reply = try_zmq do
            @zmq_client.send('get_snapshot',request) #is a hash of code, status, data
          end
          status,data = process_reply(reply)
          data
        end

        def get_streams_to_snapshot(max_threshold)
          request = JSON.generate({'max_threshold'=>max_threshold})
          reply = try_zmq do
            @zmq_client.send('get_streams_to_snapshot',request) #is a hash of code, status, data
          end
          status,data = process_reply(reply)
          data
        end

        private

        def try_zmq
          begin
            yield
          rescue e
            raise EventStore::StorageUnavailableError, e.to_s, e.backtrace
          end
        end

        def process_reply(reply)
          code,status,data = reply.values_at('code','status','data')
          return [status,data] if code == '200'
          #status will be the exception and data the backtrace
          raise(EventStore::StorageError, status, data) if code == '503'
          raise(EventStore::ConcurrencyError, status, data) if code == '423'
          raise(EventStore::DuplicateCommitError, status, data) if code == '409'
          raise(EventStore::StreamNotFoundError, status, data) if code == '422'
        end
      end
    end
  end
end