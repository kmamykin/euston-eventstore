module Euston
  module EventStore
    module Persistence
      module Sql
        class SqlPersistenceEngine
          def initialize connection_factory
            @connection_factory = connection_factory
          end

          def init

            # if (Interlocked.Increment(ref this.initialized) > 1)
            #   return;

            # this.ExecuteCommand(Guid.Empty, statement =>
            #   statement.ExecuteWithSuppression(this.Dialect.InitializeStorage));

              # try_mongo do
              #   persisted_commits.ensure_index [ ['dispatched', Mongo::ASCENDING],
              #                                    ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'dispatched_index'

              #   persisted_commits.ensure_index [ ['_id.stream_id', Mongo::ASCENDING],
              #                                    ['events.stream_revision', Mongo::ASCENDING] ], :unique => true,  :name => 'get_from_index'

              #   persisted_commits.ensure_index [ ['commit_timestamp', Mongo::ASCENDING] ], :unique => false, :name => 'commit_timestamp_index'

              #   persisted_stream_heads.ensure_index [ ['unsnapshotted', Mongo::ASCENDING] ], :unique => false, :name => 'unsnapshotted_index'
              # end
              # self
          end

          private

          def execute_command stream_id
            connection = @connection_factory.get_connection
            connection.auto_commit = false

            begin
              statement = @connection.create_statement

              begin
                yield statement
              ensure
                statement.close
              end

              connection.commit
            rescue StandardError => e
              connection.rollback
              raise e
            ensure
              connection.close
            end
          end

          # protected virtual void ExecuteCommand(Guid streamId, Action<IDbStatement> command)
          # {
          #   using (var scope = this.OpenCommandScope())
          #   using (var connection = this.ConnectionFactory.OpenMaster(streamId))
          #   using (var transaction = this.Dialect.OpenTransaction(connection))
          #   using (var statement = this.Dialect.BuildStatement(connection, transaction, scope))
          #   {
          #     try
          #     {
          #       command(statement);
          #       if (transaction != null)
          #         transaction.Commit();

          #       scope.Complete();
          #     }
          #     catch (Exception e)
          #     {
          #       if (e is ConcurrencyException || e is DuplicateCommitException || e is StorageUnavailableException)
          #         throw;

          #       throw new StorageException(e.Message, e);
          #     }
          #   }
          # }
        end
      end
    end
  end
end
