require 'singleton'

module EventStore
  module Persistence
    module Mongodb
      class Config
        include ::Singleton

        def host
          @host ||= 'localhost'
        end

        def port
          @port ||= Mongo::Connection::DEFAULT_PORT
        end

        def options
          @options ||= {}
        end

        attr_writer :host, :port, :options
        attr_accessor :database
      end
    end
  end
end