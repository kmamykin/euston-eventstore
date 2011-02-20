module EventStore
  module Persistence
    module Mongodb
      module MongoEventMessage
        extend ::ActiveSupport::Concern

        def to_hash
          {
            :headers => headers,
            :body => body.to_hash
          }
        end
      end
    end
  end

  class EventMessage
    include Persistence::Mongodb::MongoEventMessage
  end
end