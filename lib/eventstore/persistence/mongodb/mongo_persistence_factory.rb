module EventStore
  module Persistence
    module Mongodb
      class MongoPersistenceFactory
        def initialize(connection_name, serializer)
          @connection_name = connection_name
          @serializer = serializer
        end

        def build
#          connection_string =
        end
#
#		public virtual IPersistStreams Build()
#		{
#			var connectionString = this.TransformConnectionString(this.GetConnectionString());
#			var database = MongoDatabase.Create(connectionString);
#			return new MongoPersistenceEngine(database, this.serializer);
#		}
#
#		protected virtual string GetConnectionString()
#		{
#			return ConfigurationManager.ConnectionStrings[this.connectionName].ConnectionString;
#		}
#
#		protected virtual string TransformConnectionString(string connectionString)
#		{
#			return connectionString;
#		}
      end
    end
  end
end