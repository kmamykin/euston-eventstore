def build_commit_stub(stream_id, revision, sequence, length)
  events = length.times.map{ ::EventStore::EventMessage.new }
  ::EventStore::Commit.new stream_id, revision, UUID.new, sequence, Time.now.utc, nil, events
end