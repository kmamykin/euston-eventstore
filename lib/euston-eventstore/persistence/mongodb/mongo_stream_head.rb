module Euston
  module EventStore
    module Persistence
      module Mongodb
        module MongoStreamHead
          extend ActiveSupport::Concern

          class << self
            def from_hash hash
              return nil if hash.nil?
              StreamHead.new hash['_id'], hash['head_revision'], hash['snapshot_revision']
            end
          end

          def to_hash
            {
              :stream_id => @stream_id,
              :head_revision => @head_revision,
              :snapshot_revision => @snapshot_revision
            }
          end
        end
      end

      class StreamHead
        include Mongodb::MongoStreamHead
      end
    end
  end
end
