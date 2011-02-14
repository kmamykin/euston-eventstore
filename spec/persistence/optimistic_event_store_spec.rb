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

  describe 'when opening an empty stream starting a revision zero' do
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

  describe 'when opening an empty stream starting above revision zero' do
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

  describe 'when opening a populated stream' do
    let(:min_revision) { 17 }
    let(:max_revision) { 42 }
    let(:committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => min_revision,
                                               :commit_id => UUID.new,
                                               :commit_sequence => 1,
                                               :events => [ EventStore::EventMessage.new ] ) ] }

    before do
      persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
      @stream = store.open_stream stream_id, min_revision, max_revision
    end

    it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
    it('returns an event stream containing the correct stream identifier') { @stream.stream_id.should == stream_id }
  end

  describe 'when opening a populated stream from a snapshot' do
    let(:min_revision) { 42 }
    let(:max_revision) { EventStore::FIXNUM_MAX }
    let(:snapshot) { EventStore::Snapshot.new stream_id, min_revision, 'snapshot' }
    let(:committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => min_revision,
                                               :commit_id => UUID.new,
                                               :commit_sequence => 0,
                                               :events => [ EventStore::EventMessage.new ] ) ] }

    before do
      persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { @invoked = true; committed }
      store.open_stream_from_snapshot snapshot, max_revision
    end

    it('invokes the underlying infrastructure with the values provided') { @invoked.should be_true }
  end

  describe 'when opening a stream from a snapshot that is at the revision of the stream head' do
    let(:head_stream_revision) { 42 }
    let(:head_commit_sequence) { 15 }
    let(:snapshot) { EventStore::Snapshot.new stream_id, head_stream_revision, 'snapshot' }
    let(:committed) {
      EventStore::ArrayEnumerationCounter.new [
        EventStore::Commit.new(:stream_id => stream_id,
                               :stream_revision => head_stream_revision,
                               :commit_id => UUID.new,
                               :commit_sequence => head_commit_sequence,
                               :events => [ EventStore::EventMessage.new ] ) ] }

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

  describe 'when reading from revision zero' do
    before do
      persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { @invoked = true; [] }
      store.get_from stream_id, 0, EventStore::FIXNUM_MAX
    end

    it('passes a revision range to the persistence infrastructure') { @invoked.should be_true }
  end

  describe 'when reading up to revision zero' do
    let(:committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => 1,
                                               :commit_id => UUID.new,
                                               :commit_sequence => 1,
                                               :events => [ EventStore::EventMessage.new ] ) ] }

    before do
      persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { @invoked = true; committed }
      store.open_stream stream_id, 0, 0
    end

    it('passes the maximum possible revision to the persistence infrastructure') { @invoked.should be_true }
  end

  describe 'when reading up to revision zero' do
    let(:snapshot) { EventStore::Snapshot.new stream_id, 1, 'snapshot' }
    let(:committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => 1,
                                               :commit_id => UUID.new,
                                               :commit_sequence => 1,
                                               :events => [ EventStore::EventMessage.new ] ) ] }

    before do
      persistence.stub(:get_from).with(stream_id, snapshot.stream_revision, EventStore::FIXNUM_MAX) { @invoked = true; committed }
      store.open_stream_from_snapshot snapshot, 0
    end

    it('passes the maximum possible revision to the persistence infrastructure') { @invoked.should be_true }
  end

  describe 'when committing a null attempt back to the stream' do
    before do
      begin
        store.commit nil
      rescue Exception => e
        @caught = e
      end
    end

    it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
  end

  describe 'when committing with an unidentified attempt back to the stream' do
    let(:empty_identifier) { nil }
    let(:unidentified) { EventStore::Commit.new(:stream_id => stream_id,
                                               :stream_revision => 1,
                                               :commit_id => empty_identifier,
                                               :commit_sequence => 1 ) }

    before do
      begin
        store.commit unidentified
      rescue Exception => e
        @caught = e
      end
    end

    it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
  end

  describe 'when the number of commits is greater than the number of revisions' do
    let(:stream_revision) { 1 }
    let(:commit_sequence) { 2 }
    let(:corrupt) { EventStore::Commit.new(:stream_id => stream_id,
                                           :stream_revision => stream_revision,
                                           :commit_id => UUID.new,
                                           :commit_sequence => commit_sequence,
                                           :events => [ EventStore::EventMessage.new ] ) }

    before do
      begin
        store.commit corrupt
      rescue Exception => e
        @caught = e
      end
    end

    it('throws an ArgumentError') { @caught.should be_an(ArgumentError) }
  end

  describe 'when committing with a non-positive commit sequence back to the stream' do
    let(:stream_revision) { 1 }
    let(:invalid_commit_sequence) { 0 }
    let(:invalid_commit) { EventStore::Commit.new(:stream_id => stream_id,
                                                  :stream_revision => stream_revision,
                                                  :commit_id => UUID.new,
                                                  :commit_sequence => invalid_commit_sequence,
                                                  :events => [ EventStore::EventMessage.new ] ) }

    before do
      begin
        store.commit invalid_commit
      rescue Exception => e
        @caught = e
      end
    end

    it('throw an ArgumentError') { @caught.should be_an(ArgumentError) }
  end

  describe 'when committing with a non-positive stream revision back to the stream' do
    let(:invalid_stream_revision) { 0 }
    let(:commit_sequence) { 1 }
    let(:invalid_commit) { EventStore::Commit.new(:stream_id => stream_id,
                                                  :stream_revision => invalid_stream_revision,
                                                  :commit_id => UUID.new,
                                                  :commit_sequence => commit_sequence,
                                                  :events => [ EventStore::EventMessage.new ] ) }

    before do
      begin
        store.commit invalid_commit
      rescue Exception => e
        @caught = e
      end
    end

    it('throw an ArgumentError') { @caught.should be_an(ArgumentError) }
  end

  describe 'when committing with a sequence beyond the known end of a stream' do
    let(:head_stream_revision) { 5 }
    let(:head_commit_sequence) { 1 }
    let(:expected_next_commit_sequence) { head_commit_sequence + 1 }
    let(:beyond_end_of_stream_commit_sequence) { expected_next_commit_sequence + 1 }
    let(:beyond_end_of_stream) { EventStore::Commit.new(:stream_id => stream_id,
                                                        :stream_revision => head_stream_revision + 1,
                                                        :commit_id => UUID.new,
                                                        :commit_sequence => beyond_end_of_stream_commit_sequence,
                                                        :events => [ EventStore::EventMessage.new ] ) }
    let(:already_committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                                       :stream_revision => head_stream_revision,
                                                       :commit_id => UUID.new,
                                                       :commit_sequence => head_commit_sequence,
                                                       :events => [ EventStore::EventMessage.new ] )  ] }

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

  describe 'when committing with a revision beyond the known end of a stream' do
    let(:head_commit_sequence) { 1 }
    let(:head_stream_revision) { 1 }
    let(:number_of_events_being_committed) { 1 }
    let(:expected_next_stream_revision) { head_stream_revision + 1 + number_of_events_being_committed }
    let(:beyond_end_of_stream_revision) { expected_next_stream_revision + 1 }
    let(:beyond_end_of_stream) { EventStore::Commit.new(:stream_id => stream_id,
                                                        :stream_revision => beyond_end_of_stream_revision,
                                                        :commit_id => UUID.new,
                                                        :commit_sequence => head_commit_sequence + 1,
                                                        :events => [ EventStore::EventMessage.new ] ) }
    let(:already_committed) { [ EventStore::Commit.new(:stream_id => stream_id,
                                                       :stream_revision => head_stream_revision,
                                                       :commit_id => UUID.new,
                                                       :commit_sequence => head_commit_sequence,
                                                       :events => [ EventStore::EventMessage.new ] )  ] }

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
end

__END__
	public class when_committing_an_empty_attempt_to_a_stream : using_persistence
	{
		static readonly Commit attemptWithNoEvents = BuildCommitStub(Guid.NewGuid());

		Establish context = () =>
			persistence.Setup(x => x.Commit(attemptWithNoEvents));

		Because of = () =>
			((ICommitEvents)store).Commit(attemptWithNoEvents);

		It should_drop_the_commit_provided = () =>
			persistence.Verify(x => x.Commit(attemptWithNoEvents), Times.AtMost(0));
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_a_valid_and_populated_attempt_to_a_stream : using_persistence
	{
		static readonly Commit populatedAttempt = BuildCommitStub(1, 1);

		Establish context = () =>
		{
			persistence.Setup(x => x.Commit(populatedAttempt));
			dispatcher.Setup(x => x.Dispatch(populatedAttempt));
		};

		Because of = () =>
			((ICommitEvents)store).Commit(populatedAttempt);

		It should_provide_the_commit_attempt_to_the_configured_persistence_mechanism = () =>
			persistence.Verify(x => x.Commit(populatedAttempt), Times.Once());

		It should_provide_the_commit_to_the_dispatcher = () =>
			dispatcher.Verify(x => x.Dispatch(populatedAttempt), Times.Once());
	}

	/// <summary>
	/// This behavior is primarily to support a NoSQL storage solution where CommitId is not being used as the "primary key"
	/// in a NoSQL environment, we'll most likely use StreamId + CommitSequence, which also enables optimistic concurrency.
	/// </summary>
	[Subject("OptimisticEventStore")]
	public class when_committing_with_an_identifier_that_was_previously_read : using_persistence
	{
		const int MaxRevision = 2;
		static readonly Guid AlreadyCommittedId = Guid.NewGuid();
		static readonly Commit[] Committed = new[]
		{
			BuildCommitStub(AlreadyCommittedId, 1, 1),
			BuildCommitStub(Guid.NewGuid(), 1, 1)
		};
		static readonly Commit DuplicateCommitAttempt = BuildCommitStub(
			AlreadyCommittedId, Committed.Last().StreamRevision + 1, Committed.Last().CommitSequence + 1);
		static Exception thrown;

		Establish context = () =>
			persistence.Setup(x => x.GetFrom(streamId, 0, MaxRevision)).Returns(Committed);

		Because of = () =>
		{
			((ICommitEvents)store).GetFrom(streamId, 0, MaxRevision).ToList();
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(DuplicateCommitAttempt));
		};

		It should_throw_a_DuplicateCommitException = () =>
			thrown.ShouldBeOfType<DuplicateCommitException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_the_same_commit_identifier_more_than_once : using_persistence
	{
		static readonly Guid DuplicateCommitId = Guid.NewGuid();
		static readonly Commit SuccessfulCommit = BuildCommitStub(DuplicateCommitId, 1, 1);
		static readonly Commit DuplicateCommit = BuildCommitStub(DuplicateCommitId, 2, 2);
		static Exception thrown;

		Establish context = () =>
			((ICommitEvents)store).Commit(SuccessfulCommit);

		Because of = () =>
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(DuplicateCommit));

		It throw_a_DuplicateCommitException = () =>
			thrown.ShouldBeOfType<DuplicateCommitException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_a_sequence_less_or_equal_to_the_most_recent_sequence_for_the_stream : using_persistence
	{
		const int HeadStreamRevision = 42;
		const int HeadCommitSequence = 42;
		const int DupliateCommitSequence = HeadCommitSequence;
		static readonly Commit[] Committed = new[] { BuildCommitStub(HeadStreamRevision, HeadCommitSequence) };
		private static readonly Commit Attempt = BuildCommitStub(HeadStreamRevision + 1, DupliateCommitSequence);

		static Exception thrown;

		Establish context = () =>
			persistence.Setup(x => x.GetFrom(streamId, HeadStreamRevision, int .MaxValue)).Returns(Committed);

		Because of = () =>
		{
			((ICommitEvents)store).GetFrom(streamId, HeadStreamRevision, int.MaxValue).ToList();
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(Attempt));
		};

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_a_revision_less_or_equal_to_than_the_most_recent_revision_read_for_the_stream : using_persistence
	{
		const int HeadStreamRevision = 3;
		const int HeadCommitSequence = 2;
		const int DuplicateStreamRevision = HeadStreamRevision;
		static readonly Commit[] Committed = new[] { BuildCommitStub(HeadStreamRevision, HeadCommitSequence) };
		static readonly Commit FailedAttempt = BuildCommitStub(DuplicateStreamRevision, HeadCommitSequence + 1);

		static Exception thrown;

		Establish context = () =>
			persistence.Setup(x => x.GetFrom(streamId, HeadStreamRevision, int.MaxValue)).Returns(Committed);

		Because of = () =>
		{
			((ICommitEvents)store).GetFrom(streamId, HeadStreamRevision, int.MaxValue).ToList();
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(FailedAttempt));
		};

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_a_commit_sequence_less_than_or_equal_to_the_most_recent_commit_for_the_stream : using_persistence
	{
		const int DuplicateCommitSequence = 1;

		static readonly Commit SuccessfulAttempt = BuildCommitStub(1, DuplicateCommitSequence);
		static readonly Commit FailedAttempt = BuildCommitStub(2, DuplicateCommitSequence);
		static Exception thrown;

		Establish context = () =>
			((ICommitEvents)store).Commit(SuccessfulAttempt);

		Because of = () =>
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(FailedAttempt));

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_committing_with_a_stream_revision_less_than_or_equal_to_the_most_recent_commit_for_the_stream : using_persistence
	{
		const int DuplicateStreamRevision = 2;

		static readonly Commit SuccessfulAttempt = BuildCommitStub(DuplicateStreamRevision, 1);
		static readonly Commit FailedAttempt = BuildCommitStub(DuplicateStreamRevision, 2);
		static Exception thrown;

		Establish context = () =>
			((ICommitEvents)store).Commit(SuccessfulAttempt);

		Because of = () =>
			thrown = Catch.Exception(() => ((ICommitEvents)store).Commit(FailedAttempt));

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();
	}

	[Subject("OptimisticEventStore")]
	public class when_disposing_the_event_store : using_persistence
	{
		private Because of = () =>
		{
			store.Dispose();
			store.Dispose();
		};

		It should_dispose_the_underlying_persistence_exactly_once = () =>
			persistence.Verify(x => x.Dispose(), Times.Once());

		It should_dispose_the_underlying_dispatcher_exactly_once = () =>
			dispatcher.Verify(x => x.Dispose(), Times.Once());
	}