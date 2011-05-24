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
          @port ||= 27017
        end

        def options
          @options ||= { :safe => { :fsync => true }}
        end

        attr_writer :host, :port, :options
        attr_accessor :database
      end
    end
  end
end
