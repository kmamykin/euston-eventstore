require_relative '../spec_helper'

describe EventStore do
  let(:default_stream_revision) { 1 }
  let(:default_commit_sequence) { 1 }
  let(:stream_id) { UUID.new }
  let(:persistence) { double('persistence') }
  let(:stream) { EventStore::OptimisticEventStream.new stream_id, persistence }

  after { stream_id = UUID.new }

  describe 'optimistic event stream' do
    context 'when constructing a new stream' do
      let(:min_revision) { 2 }
      let(:max_revision) { 7 }
      let(:commit_length) { 2 }
      let(:committed) { [
          build_commit_stub(stream_id, 2, 1, commit_length),
          build_commit_stub(stream_id, 4, 2, commit_length),
          build_commit_stub(stream_id, 6, 3, commit_length),
          build_commit_stub(stream_id, 8, 3, commit_length)
      ] }
    
      before do
        persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { committed }
        @stream = EventStore::OptimisticEventStream.new stream_id, persistence, min_revision, max_revision
      end
      
      it 'has the correct stream identifier' do
        @stream.stream_id.should == stream_id
      end

      it 'has the correct head stream revision' do
        @stream.stream_revision.should == max_revision
      end

      it 'has the correct head commit sequence' do
        @stream.commit_sequence.should == committed.last.commit_sequence
      end

      it 'does not include the event below the minimum revision indicated' do
        @stream.committed_events.first.should == committed.first.events.last
      end

      it 'does not include events above the maximum revision indicated' do
        @stream.committed_events.last.should == committed.last.events.first
      end

      it 'has all of the committed events up to the stream revision specified' do
        @stream.committed_events.length.should == max_revision - min_revision + 1
      end
    end

    context 'when constructing the head event revision is less than the max desired revision' do
      let(:commit_length) { 2 }
      let(:committed) { [
          build_commit_stub(stream_id, 2, 1, commit_length),
          build_commit_stub(stream_id, 4, 2, commit_length),
          build_commit_stub(stream_id, 6, 3, commit_length),
          build_commit_stub(stream_id, 8, 3, commit_length)
      ] }

      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { committed }
        @stream = EventStore::OptimisticEventStream.new stream_id, persistence, 0, EventStore::FIXNUM_MAX
      end

      it 'sets the stream revision to the revision of the most recent event' do
        @stream.stream_revision.should == committed.last.stream_revision
      end
    end

    context 'when adding a null event message' do
      before do
        begin
          stream << nil
        rescue Exception => e
          @exception = e
        end
      end

      it 'raises an ArgumentError' do
        @exception.should be_an(ArgumentError)
      end
    end
  end
end