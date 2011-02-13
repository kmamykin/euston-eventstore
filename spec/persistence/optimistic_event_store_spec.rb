require_relative '../spec_helper'

describe ::EventStore do
  let(:stream_id) { UUID.new }
  let(:persistence) { double('persistence') }
  let(:dispatcher) { double('dispatcher') }
  let(:store) { EventStore::OptimisticEventStore.new persistence, dispatcher }

  after { stream_id = UUID.new }

  describe 'optimistic event store' do
    context 'when creating a stream' do
      let(:stream) { store.create_stream stream_id }

      it('returns a new stream') { stream.should_not be_nil }
      it('returns a stream with the correct stream identifier') { stream.stream_id.should == stream_id }
      it('returns a stream with a zero stream revision') { stream.stream_revision.should == 0 }
      it('returns a stream with a zero commit sequence') { stream.commit_sequence.should == 0 }
      it('returns a stream with no committed events') { stream.committed_events.should have(0).items }
      it('returns a stream with no uncommitted events') { stream.uncommitted_events.should have(0).items }
    end
  end

  describe 'when opening a stream' do
    let(:min_revision) { 17 }
    let(:max_revision) { 42 }
    let(:committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => min_revision,
                                               :commit_id => UUID.new,
                                               :events => [ EventStore::EventMessage.new ] ) ] }

    before do
      persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
      @stream = store.open_stream stream_id, min_revision, max_revision
    end

    it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
    it('returns an event stream containing the correct stream identifier') { @stream.stream_id.should == stream_id }
  end

  describe 'when opening an empty stream' do
    before do
      persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { [] }
      
      begin
        store.open_stream stream_id, 0, 0
      rescue Exception => e
        @caught = e
      end
    end

    it('throws a StreamNotFoundError') { @caught.should be_an(EventStore::StreamNotFoundError)  }
  end
end