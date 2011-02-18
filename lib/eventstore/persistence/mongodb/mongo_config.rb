module EventStore
  module Persistence
    module Mongodb
      class Config
        include Singleton

        def connection_string

        end
      end
    end
  end
end