module Euston
  module EventStore
    module Persistence
      module Sql
        class SqlPersistenceFactory
          def self.build
            config = Config.instance

            Java::com.mysql.jdbc.Driver
            @connection = java.sql.DriverManager.get_connection config.uri, config.username, config.password

            SqlPersistenceEngine.new @connection
          end
        end
      end
    end
  end
end
