require_relative '../spec_helper'

describe ::EventStore do
  let(:uuid) { UUID.new }
  let(:stream_id) { uuid.generate }
  let(:persistence) { double('persistence').as_null_object }
  let(:store) { EventStore::OptimisticEventStore.new persistence }

  after { stream_id = uuid.generate }

  describe 'optimistic event store' do
    context 'when creating a stream' do
      let(:stream) { store.create_stream stream_id }

      it('returns a new stream') { stream.should_not be_nil }
      it('returns a stream with the correct stream identifier') { stream.stream_id.should == stream_id }
      it('returns a stream with a zero stream revision') { stream.stream_revision.should == 0 }
      it('returns a stream with a zero commit sequence') { stream.commit_sequence.should == 0 }
      it('returns a stream with no committed events') { stream.committed_events.should have(0).items }
      it('returns a stream with no uncommitted events') { stream.uncommitted_events.should have(0).items }
      it('returns a stream with no uncommitted headers') { stream.uncommitted_headers.should have(0).items }
    end

    context 'when opening an empty stream starting at revision zero' do
      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => 0,
                                           :max_revision => EventStore::FIXNUM_MAX }) { [] }

        @stream = store.open_stream :stream_id => stream_id, :min_revision => 0, :max_revision => 0
      end

      it('returns a new stream') { @stream.should_not be_nil }
      it('returns a stream with the correct stream identifier') { @stream.stream_id.should == stream_id }
      it('returns a stream with a zero stream revision') { @stream.stream_revision.should == 0 }
      it('returns a stream with a zero commit sequence') { @stream.commit_sequence.should == 0 }
      it('returns a stream with no committed events') { @stream.committed_events.should have(0).items }
      it('returns a stream with no uncommitted events') { @stream.uncommitted_events.should have(0).items }
      it('returns a stream with no uncommitted headers') { @stream.uncommitted_headers.should have(0).items }
    end

    context 'when opening an empty stream starting above revision zero' do
      let(:min_revision) { 1 }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => min_revision,
                                           :max_revision => EventStore::FIXNUM_MAX }) { [] }

        begin
          store.open_stream :stream_id => stream_id,
                            :min_revision => min_revision,
                            :max_revision => EventStore::FIXNUM_MAX
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a StreamNotFoundError') { @caught.should be_an(EventStore::StreamNotFoundError)  }
    end

    context 'when opening a populated stream' do
      let(:min_revision) { 17 }
      let(:max_revision) { 42 }
      let(:committed) { [ commit(:stream_revision => min_revision,
                                 :commit_sequence => 1) ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => min_revision,
                                           :max_revision => max_revision }) { @invoked = true; committed }

        @stream = store.open_stream :stream_id => stream_id,
                                    :min_revision => min_revision,
                                    :max_revision => max_revision
      end

      it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
      it('returns an event stream containing the correct stream identifier') { @stream.stream_id.should == stream_id }
    end

    context 'when opening a populated stream' do
      let(:min_revision) { 17 }
      let(:max_revision) { 42 }
      let(:committed) { [ commit(:stream_revision => min_revision) ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => min_revision,
                                           :max_revision => max_revision }) { @invoked = true; committed }

        @stream = store.open_stream :stream_id => stream_id,
                                    :min_revision => min_revision,
                                    :max_revision => max_revision
      end

      it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
      it('returns an event stream containing the correct stream identifier') { @stream.stream_id.should == stream_id }
    end

    context 'when opening a populated stream from a snapshot' do
      let(:min_revision) { 42 }
      let(:max_revision) { EventStore::FIXNUM_MAX }
      let(:snapshot) { EventStore::Snapshot.new stream_id, min_revision, 'snapshot' }
      let(:committed) { [ commit(:stream_revision => min_revision, :commit_sequence => 0) ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => min_revision,
                                           :max_revision => max_revision }) { @invoked = true; committed }

        store.open_stream :snapshot => snapshot,
                          :max_revision => max_revision
      end

      it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
    end

    context 'when opening a stream from a snapshot that is at the revision of the stream head' do
      let(:head_stream_revision) { 42 }
      let(:head_commit_sequence) { 15 }
      let(:snapshot) { EventStore::Snapshot.new stream_id, head_stream_revision, 'snapshot' }
      let(:committed) { EventStore::ArrayEnumerationCounter.new [ commit(:stream_revision => head_stream_revision,
                                                                         :commit_sequence => head_commit_sequence) ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => head_stream_revision,
                                           :max_revision => EventStore::FIXNUM_MAX }) { committed }

        @stream = store.open_stream :snapshot => snapshot,
                                    :max_revision => EventStore::FIXNUM_MAX
      end

      it('returns a stream with the correct stream identifier') { @stream.stream_id.should == stream_id }
      it('returns a stream with the revision of the stream head') { @stream.stream_revision.should == head_stream_revision }
      it('returns a stream with a commit sequence of the stream head') { @stream.commit_sequence.should == head_commit_sequence }
      it('returns a stream with no committed events') { @stream.committed_events.should have(0).items }
      it('returns a stream with no uncommitted events') { @stream.uncommitted_events.should have(0).items }
      it('only enumerates the set of commits once') { committed.invocations.should == 1 }
    end

    context 'when reading from revision zero' do
      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => 0,
                                           :max_revision => EventStore::FIXNUM_MAX }) { @invoked = true; [] }

        store.get_from stream_id, 0, EventStore::FIXNUM_MAX
      end

      it('passes a revision range to the persistence infrastructure') { @invoked.should be_true }
    end

    describe 'when reading up to revision zero' do
      let(:committed) { [ commit ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => 0,
                                           :max_revision => EventStore::FIXNUM_MAX }) { @invoked = true; committed }

        store.open_stream :stream_id => stream_id,
                          :min_revision => 0,
                          :max_revision => 0
      end

      it('passes the maximum possible revision to the persistence infrastructure') { @invoked.should be_true }
    end

    context 'when reading from a snapshot up to revision zero' do
      let(:snapshot) { EventStore::Snapshot.new stream_id, 1, 'snapshot' }
      let(:committed) { [ commit ] }

      before do
        persistence.stub(:get_from).with({ :stream_id => stream_id,
                                           :min_revision => snapshot.stream_revision,
                                           :max_revision => EventStore::FIXNUM_MAX }) { @invoked = true; committed }

        store.open_stream :snapshot => snapshot,
                          :max_revision => 0
      end

      it('passes the maximum possible revision to the persistence infrastructure') { @invoked.should be_true }
    end

    context 'when committing a null attempt back to the stream' do
      before do
        begin
          store.commit nil
        rescue Exception => e
          @caught = e
        end
      end

      it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
    end

    context 'when committing with an unidentified attempt back to the stream' do
      let(:empty_identifier) { nil }
      let(:unidentified) { commit(:commit_id => empty_identifier, :events => [] ) }

      before do
        begin
          store.commit unidentified
        rescue Exception => e
          @caught = e
        end
      end

      it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
    end

    context 'when the number of commits is greater than the number of revisions' do
      let(:stream_revision) { 1 }
      let(:commit_sequence) { 2 }
      let(:corrupt) { commit(:stream_revision => stream_revision, :commit_sequence => commit_sequence) }

      before do
        begin
          store.commit corrupt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
    end

    context 'when committing with a non-positive commit sequence back to the stream' do
      let(:stream_revision) { 1 }
      let(:invalid_commit_sequence) { 0 }
      let(:invalid_commit) { commit(:stream_revision => stream_revision, :commit_sequence => invalid_commit_sequence) }

      before do
        begin
          store.commit invalid_commit
        rescue Exception => e
          @caught = e
        end
      end

      it('throw an ArgumentError') { @caught.should be_an(ArgumentError) }
    end

    context 'when committing with a non-positive stream revision back to the stream' do
      let(:invalid_stream_revision) { 0 }
      let(:commit_sequence) { 1 }
      let(:invalid_commit) { commit(:stream_revision => invalid_stream_revision, :commit_sequence => commit_sequence) }

      before do
        begin
          store.commit invalid_commit
        rescue Exception => e
          @caught = e
        end
      end

      it('throw an ArgumentError') { @caught.should be_an(ArgumentError) }
    end

    context 'when committing an empty attempt to a stream' do
      let(:attempt_with_no_events) { commit }

      before do
        persistence.stub(:commit).with(attempt_with_no_events) { @invoked = true }
      end

      it('drops the commit provided') { @invoked.should be_nil }
    end

    context 'when committing with a valid and populated attempt to a stream' do
      let(:populated_attempt) { commit }

      before do
        persistence.stub(:commit).with(populated_attempt) { @commit_invoked = true }

        store.commit populated_attempt
      end

      it('provides the commit attempt to the configured persistence mechanism') { @commit_invoked.should be_true }
    end
  end

  def commit(options = {})
    defaults = { :stream_id => stream_id,
                 :commit_id => uuid.generate,
                 :events => [ EventStore::EventMessage.new ]}

    EventStore::Commit.new(defaults.merge options)
  end
end
