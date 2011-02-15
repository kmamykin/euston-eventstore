require_relative '../spec_helper'

describe ::EventStore do
  let(:stream_id) { UUID.new }
  let(:persistence) { double('persistence').as_null_object }
  let(:dispatcher) { double('dispatcher').as_null_object }
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

    context 'when opening a stream' do
      let(:min_revision) { 17 }
      let(:max_revision) { 42 }
      let(:committed) { [ commit(:stream_revision => min_revision) ] }

      before do
        persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
        @stream = store.open_stream stream_id, min_revision, max_revision
      end

      it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
      it('returns an event stream containing the correct stream identifier') { @stream.stream_id.should == stream_id }
    end

    context 'when opening an empty stream starting a revision zero' do
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

    context 'when opening an empty stream starting above revision zero' do
      let(:min_revision) { 1 }

      before do
        persistence.stub(:get_from).with(stream_id, min_revision, EventStore::FIXNUM_MAX) { [] }

        begin
          store.open_stream stream_id, min_revision, EventStore::FIXNUM_MAX
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a StreamNotFoundError') { @caught.should be_an(EventStore::StreamNotFoundError)  }
    end

    context 'when opening a populated stream' do
      let(:min_revision) { 17 }
      let(:max_revision) { 42 }
      let(:committed) { [ commit(:stream_revision => min_revision) ] }

      before do
        persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
        @stream = store.open_stream stream_id, min_revision, max_revision
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
        persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
        store.open_stream_from_snapshot snapshot, max_revision
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
        persistence.stub(:get_from).with(stream_id, head_stream_revision, EventStore::FIXNUM_MAX) { committed }
        @stream = store.open_stream_from_snapshot snapshot, EventStore::FIXNUM_MAX
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
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { @invoked = true; [] }
        store.get_from stream_id, 0, EventStore::FIXNUM_MAX
      end

      it('passes a revision range to the persistence infrastructure') { @invoked.should be_true }
    end

    describe 'when reading up to revision zero' do
      let(:committed) { [ commit ] }

      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { @invoked = true; committed }
        store.open_stream stream_id, 0, 0
      end

      it('passes the maximum possible revision to the persistence infrastructure') { @invoked.should be_true }
    end

    context 'when reading up to revision zero' do
      let(:snapshot) { EventStore::Snapshot.new stream_id, 1, 'snapshot' }
      let(:committed) { [ commit ] }

      before do
        persistence.stub(:get_from).with(stream_id, snapshot.stream_revision, EventStore::FIXNUM_MAX) { @invoked = true; committed }
        store.open_stream_from_snapshot snapshot, 0
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

    context 'when committing with a sequence beyond the known end of a stream' do
      let(:head_stream_revision) { 5 }
      let(:head_commit_sequence) { 1 }
      let(:expected_next_commit_sequence) { head_commit_sequence + 1 }
      let(:beyond_end_of_stream_commit_sequence) { expected_next_commit_sequence + 1 }
      let(:beyond_end_of_stream) { commit(:stream_revision => head_stream_revision + 1, :commit_sequence => beyond_end_of_stream_commit_sequence) }
      let(:already_committed) { [ commit(:stream_revision => head_stream_revision, :commit_sequence => head_commit_sequence) ] }

      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { already_committed }
        store.get_from stream_id, 0, EventStore::FIXNUM_MAX

        begin
          store.commit beyond_end_of_stream
        rescue Exception => e
          @caught = e
        end
      end

      it('throw a StorageError') { @caught.should be_an(EventStore::StorageError) }
    end

    context 'when committing with a revision beyond the known end of a stream' do
      let(:head_commit_sequence) { 1 }
      let(:head_stream_revision) { 1 }
      let(:number_of_events_being_committed) { 1 }
      let(:expected_next_stream_revision) { head_stream_revision + 1 + number_of_events_being_committed }
      let(:beyond_end_of_stream_revision) { expected_next_stream_revision + 1 }
      let(:beyond_end_of_stream) { commit(:stream_revision => beyond_end_of_stream_revision, :commit_sequence => head_commit_sequence + 1) }
      let(:already_committed) { [ commit(:stream_revision => head_stream_revision, :commit_sequence => head_commit_sequence) ] }

      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { already_committed }
        store.get_from stream_id, 0, EventStore::FIXNUM_MAX

        begin
          store.commit beyond_end_of_stream
        rescue Exception => e
          @caught = e
        end
      end

      it('throw a StorageError') { @caught.should be_an(EventStore::StorageError) }
    end

    context 'when committing an empty attempt to a stream' do
      let(:attempt_with_no_events) { commit }

      before do
        persistence.stub(:commit).with(attempt_with_no_events) { @invoked = true }
      end

      it('drops the commit provided') { @invoked.should be_nil }
    end

    context 'when committing with a valid an populated attempt to a stream' do
      let(:populated_attempt) { commit }

      before do
        persistence.stub(:commit).with(populated_attempt) { @commit_invoked = true }
        dispatcher.stub(:dispatch).with(populated_attempt) { @dispatch_invoked = true }

        store.commit populated_attempt
      end

      it('provides the commit attempt to the configured persistence mechanism') { @commit_invoked.should be_true }
      it('provides the commit to the dispatcher') { @dispatch_invoked.should be_true }
    end

    # This behavior is primarily to support a NoSQL storage solution where CommitId is not being used as the "primary key"
    #	in a NoSQL environment, we'll most likely use StreamId + CommitSequence, which also enables optimistic concurrency.
    context 'when committing with an identifier that was previously read' do
      let(:max_revision) { 2 }
      let(:already_committed_id) { UUID.new }
      let(:committed) { [ commit(:commit_id => already_committed_id), commit ] }
      let(:duplicate_commit_attempt) { commit(:stream_revision => committed.last.stream_revision + 1,
                                              :commit_id => already_committed_id,
                                              :commit_sequence => committed.last.commit_sequence + 1) }

      before do
        persistence.stub(:get_from).with(stream_id, 0, max_revision) { committed }
        store.get_from stream_id, 0, max_revision

        begin
          store.commit duplicate_commit_attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a DuplicateCommitError') { @caught.should be_an(EventStore::DuplicateCommitError) }
    end

    context 'when committing with the same commit identifier more than once' do
      let(:duplicate_commit_id) { UUID.new }
      let(:successful_commit) { commit(:commit_id => duplicate_commit_id) }
      let(:duplicate_commit) { commit(:stream_revision => 2, :commit_id => duplicate_commit_id, :commit_sequence => 2) }

      before do
        store.commit successful_commit

        begin
          store.commit duplicate_commit
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a DuplicateCommitError') { @caught.should be_an(EventStore::DuplicateCommitError) }
    end

    context 'when committing with a sequence less or equal to the most recent sequence for the stream' do
      let(:head_commit_sequence) { 42 }
      let(:head_stream_revision) { 42 }
      let(:duplicate_commit_sequence) { head_commit_sequence }
      let(:committed) { [ commit(:stream_revision => head_stream_revision, :commit_sequence => head_commit_sequence) ] }
      let(:attempt) { commit(:stream_revision => head_stream_revision + 1, :commit_sequence => duplicate_commit_sequence) }

      before do
        persistence.stub(:get_from).with(stream_id, head_stream_revision, EventStore::FIXNUM_MAX) { committed }
        store.get_from stream_id, head_stream_revision, EventStore::FIXNUM_MAX

        begin
          store.commit attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when committing with a revision less than or equal to the most recent revision read for the stream' do
      let(:head_stream_revision) { 3 }
      let(:head_commit_sequence) { 2 }
      let(:duplicate_stream_revision) { head_stream_revision }
      let(:committed) { [ commit(:stream_revision => head_stream_revision, :commit_sequence => head_commit_sequence) ] }
      let(:failed_attempt) { commit(:stream_revision => duplicate_stream_revision, :commit_sequence => head_commit_sequence + 1) }

      before do
        persistence.stub(:get_from).with(stream_id, head_stream_revision, EventStore::FIXNUM_MAX) { committed }
        store.get_from stream_id, head_stream_revision, EventStore::FIXNUM_MAX

        begin
          store.commit failed_attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when committing with a commit sequence less than or equal to the most recent commit for the stream' do
      let(:duplicate_commit_sequence) { 1 }
      let(:successful_attempt) { commit(:commit_sequence => duplicate_commit_sequence) }
      let(:failed_attempt) { commit(:stream_revision => 2, :commit_sequence => duplicate_commit_sequence) }

      before do
        store.commit successful_attempt

        begin
          store.commit failed_attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when committing with a stream revision less than or equal to the most recent commit for the stream' do
      let(:duplicate_stream_revision) { 2 }
      let(:successful_attempt) { commit(:stream_revision => duplicate_stream_revision) }
      let(:failed_attempt) { commit(:stream_revision => duplicate_stream_revision, :commit_sequence => 2) }

      before do
        store.commit successful_attempt

        begin
          store.commit failed_attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('throws a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end
  end

  def commit(options = {})
    defaults = { :stream_id => stream_id,
                 :commit_id => UUID.new,
                 :events => [ EventStore::EventMessage.new ]}

    EventStore::Commit.new(defaults.merge options)
  end
end