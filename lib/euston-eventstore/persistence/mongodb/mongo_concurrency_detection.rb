module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoConcurrencyDetection
          extend ActiveSupport::Concern

          module InstanceMethods
            def mongo_error_types_for_current_ruby_platform
              errors = [ Mongo::OperationFailure ]
              errors << NativeException if RUBY_PLATFORM.to_s == 'java'
              errors
            end

            def detect_mongo_concurrency opts = {}, &block
              begin
                yield
              rescue *mongo_error_types_for_current_ruby_platform => e
                if e.message.include? "E11000"
                  opts.fetch(:on_e11000_error, ->(ex) { raise ConcurrencyError }).call e
                else
                  opts.fetch(:on_other_error, ->(ex) { raise ex }).call e
                end
              end
            end
          end
        end
      end
    end
  end
end
