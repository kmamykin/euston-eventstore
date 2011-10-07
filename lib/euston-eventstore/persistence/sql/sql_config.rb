require 'singleton'

module Euston
  module EventStore
    module Persistence
      module Sql
        class Config
          include ::Singleton

          def uri
            @uri ||= 'jdbc:mysql://0.0.0.0:3306/euston-eventstore'
          end

          attr_writer :uri
          attr_accessor :database, :logger, :username, :password
        end
      end
    end
  end
end
