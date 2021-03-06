require 'singleton'

module Euston
  module EventStore
    module Persistence
      module Mongodb
        class Config
          include ::Singleton

          def uri
            @uri ||= 'mongodb://0.0.0.0:27017/?safe=true;fsync=true;w=1;'
          end

          attr_writer :uri
          attr_accessor :database, :logger
        end
      end
    end
  end
end
