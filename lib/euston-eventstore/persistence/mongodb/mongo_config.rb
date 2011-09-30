require 'singleton'

module Euston
  module EventStore
    module Persistence
      module Mongodb
        class Config
          include ::Singleton

          def uri
            @uri ||= 'mongodb://0.0.0.0:27017/'
          end

          def options
            @options ||= { :safe => true, :fsync => true, :journal => true }
          end

          attr_writer :uri, :options
          attr_accessor :database, :logger
        end
      end
    end
  end
end
