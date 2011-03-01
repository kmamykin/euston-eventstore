require_relative '../../spec_helper'

describe ::EventStore do
  describe 'mongodb persistence' do
    let(:uuid) { UUID.new }
    let(:database) { 'event_store_tests' }
    let(:config) { EventStore::Persistence::Mongodb::Config }
    let(:factory) { EventStore::Persistence::Mongodb::MongoPersistenceFactory }
    let(:stream_id) { uuid.generate }

    before do
      config.instance.database = database

      @persistence = factory.build
      @persistence.init
    end

    context 'when a commit is successfully persisted' do
      let(:now) { Time.now.utc + (60 * 60 * 24 * 7 * 52) }
      let(:attempt) { new_attempt(:commit_timestamp => now) }

      before do
        @persistence.commit attempt

        sleep 0.25

        @persisted = @persistence.get_from(:stream_id => stream_id,
                                           :min_revision => 0,
                                           :max_revision => EventStore::FIXNUM_MAX).first
      end

      it('correctly persists the stream identifier') { @persisted.stream_id.should == attempt.stream_id }
      it('correctly persists the stream revision') { @persisted.stream_revision.should == attempt.stream_revision }
      it('correctly persists the commit identifier') { @persisted.commit_id.should == attempt.commit_id }
      it('correctly persists the commit sequence') { @persisted.commit_sequence.should == attempt.commit_sequence }

		  # persistence engines have varying levels of precision with respect to time.
		  it('correctly persists the commit timestamp') { (@persisted.commit_timestamp - now).should be <= 1 }

      it('correctly persists the headers') { @persisted.headers.should have(attempt.headers.length).items }
      it('correctly persists the events') { @persisted.events.should have(attempt.events.length).items }
      it('makes the commit available to be read from the stream') {
        @persistence.get_from(:stream_id => stream_id,
                              :min_revision => 0,
                              :max_revision => EventStore::FIXNUM_MAX).first.commit_id.should == attempt.commit_id }

      it('adds the commit to the set of undispatched commits') {
			  @persistence.get_undispatched_commits.detect { |x| x.commit_id == attempt.commit_id }.should_not be_nil }

      it('causes the stream to be found in the list of streams to snapshot') {
        @persistence.get_streams_to_snapshot(1).detect { |x| x.stream_id == stream_id }.should_not be_nil }
    end

    context 'when a commit is successfully persisted' do
      let(:load_from_commit_containing_revision) { 3 }
      let(:up_to_commit_containing_revision) { 5 }
      let(:oldest) { new_attempt }
      let(:oldest2) { next_attempt(oldest) }
      let(:oldest3) { next_attempt(oldest2) }
      let(:newest) { next_attempt(oldest3) }

      before do
        @persistence.commit oldest
        @persistence.commit oldest2
        @persistence.commit oldest3
        @persistence.commit newest

        @committed = @persistence.get_from(:stream_id => stream_id,
                                           :min_revision => load_from_commit_containing_revision,
                                           :max_revision => up_to_commit_containing_revision).to_a
      end

      it('starts from the commit which contains the minimum stream revision specified') { @committed.first.commit_id.should == oldest2.commit_id }
      it('reads up to the commit which contains the maximum stream revision specified') { @committed.last.commit_id.should == oldest3.commit_id }
    end

    context 'when committing a stream with the same revision' do
      let(:persistence1) { factory.build }
      let(:persistence2) { factory.build }
      let(:attempt1) { new_attempt }
      let(:attempt2) { new_attempt }

      before do
        persistence1.init
        persistence2.init

        persistence1.commit attempt1

        begin
          persistence2.commit attempt2
        rescue Exception => e
          @caught = e
        end
      end

      it('raises a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when committing a stream with the same sequence' do
      let(:persistence1) { factory.build }
      let(:persistence2) { factory.build }
      let(:attempt1) { new_attempt }
      let(:attempt2) { new_attempt }

      before do
        persistence1.init
        persistence2.init

        persistence1.commit attempt1

        begin
          persistence2.commit attempt2
        rescue Exception => e
          @caught = e
        end
      end

      it('raises a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when attempting to overwrite a committed sequence' do
      let(:successful_attempt) { new_attempt }
      let(:failed_attempt) { new_attempt }

      before do
        @persistence.commit successful_attempt

        begin
          @persistence.commit failed_attempt
        rescue Exception => e
          @caught = e
        end
      end

      # POSSIBLE ERROR:
      it('raises a ConcurrencyError') { @caught.should be_an(EventStore::ConcurrencyError) }
    end

    context 'when attempting to persist a commit twice' do
      let(:attempt) { new_attempt }

      before do
        @persistence.commit attempt

        begin
          @persistence.commit attempt
        rescue Exception => e
          @caught = e
        end
      end

      it('raises a DuplicateCommitError') { @caught.should be_an(EventStore::DuplicateCommitError) }
    end

    context 'when a commit has been marked as dispatched' do
      let(:attempt) { new_attempt }

      before do
        @persistence.commit attempt
        @persistence.mark_commit_as_dispatched attempt
      end

      it('is no longer found in the set of undispatched commits') {
        @persistence.get_undispatched_commits.detect { |c| c.commit_id == attempt.commit_id }.should be_nil }
    end

    def new_attempt(options = {})
      defaults = { :stream_id => stream_id,
                   :stream_revision => 2,
                   :commit_id => uuid.generate,
                   :commit_sequence => 1,
                   :commit_timestamp => Time.now.utc,
                   :headers => { 'A header' => 'A string value',
                                 'Another header' => 2 },
                   :events => [ EventStore::EventMessage.new(:some_property => 'test'),
                                EventStore::EventMessage.new(:some_property => 'test2') ] }

      EventStore::Commit.new(defaults.merge options)
    end

    def next_attempt(attempt)
      EventStore::Commit.new(:stream_id => attempt.stream_id,
                             :stream_revision => attempt.stream_revision + 2,
                             :commit_id => uuid.generate,
                             :commit_sequence => attempt.commit_sequence + 1,
                             :commit_timestamp => attempt.commit_timestamp,
                             :headers => {},
                             :events => [ EventStore::EventMessage.new(:some_property => 'Another test'),
                                          EventStore::EventMessage.new(:some_property => 'Another test2') ])
    end

    context 'when saving a snapshot' do
      let(:snapshot) { EventStore::Snapshot.new stream_id, 1, 'snapshot' }

      before do
        @persistence.commit new_attempt
        @added = @persistence.add_snapshot snapshot
      end

      it('indicates the snapshot was added') { added.should be_true }
      it('is able to retrieve the snapshot') { @persistence.get_snapshot(stream_id, snapshot.stream_revision).should_not be_nil }
    end
  end
end

__END__

	[Subject("Persistence")]
	public class when_saving_a_snapshot : using_the_persistence_engine
	{
		static readonly Snapshot snapshot = new Snapshot(streamId, 1, "Snapshot");
		static bool added;

		Establish context = () =>
			persistence.Commit(streamId.BuildAttempt());

		Because of = () =>
			added = persistence.AddSnapshot(snapshot);

		It should_indicate_the_snapshot_was_added = () =>
			added.ShouldBeTrue();

		It should_be_able_to_retrieve_the_snapshot = () =>
			persistence.GetSnapshot(streamId, snapshot.StreamRevision).ShouldNotBeNull();
	}

	[Subject("Persistence")]
	public class when_retrieving_a_snapshot : using_the_persistence_engine
	{
		static readonly Snapshot tooFarBack = new Snapshot(streamId, 1, string.Empty);
		static readonly Snapshot correct = new Snapshot(streamId, 3, "Snapshot");
		static readonly Snapshot tooFarForward = new Snapshot(streamId, 5, string.Empty);
		static Snapshot snapshot;

		Establish context = () =>
		{
			var commit1 = streamId.BuildAttempt();
			var commit2 = commit1.BuildNextAttempt();
			var commit3 = commit2.BuildNextAttempt();
			persistence.Commit(commit1); // rev 1-2
			persistence.Commit(commit2); // rev 3-4
			persistence.Commit(commit3); // rev 5-6

			persistence.AddSnapshot(tooFarBack);
			persistence.AddSnapshot(correct);
			persistence.AddSnapshot(tooFarForward);
		};

		Because of = () =>
			snapshot = persistence.GetSnapshot(streamId, tooFarForward.StreamRevision - 1);

		It should_load_the_most_recent_prior_snapshot = () =>
			snapshot.StreamRevision.ShouldEqual(correct.StreamRevision);

		It should_have_the_correct_snapshot_payload = () =>
			snapshot.Payload.ShouldEqual(correct.Payload);
	}

	[Subject("Persistence")]
	public class when_a_snapshot_has_been_added_to_the_most_recent_commit_of_a_stream : using_the_persistence_engine
	{
		const string SnapshotData = "snapshot";
		static readonly Commit oldest = streamId.BuildAttempt();
		static readonly Commit oldest2 = oldest.BuildNextAttempt();
		static readonly Commit newest = oldest2.BuildNextAttempt();

		Establish context = () =>
		{
			persistence.Commit(oldest);
			persistence.Commit(oldest2);
			persistence.Commit(newest);
		};

		Because of = () =>
			persistence.AddSnapshot(new Snapshot(streamId, newest.StreamRevision, SnapshotData));

		It should_no_longer_find_the_stream_in_the_set_of_streams_to_be_snapshot = () =>
			persistence.GetStreamsToSnapshot(1).Any(x => x.StreamId == streamId).ShouldBeFalse();
	}

	[Subject("Persistence")]
	public class when_reading_all_commits_from_a_particular_point_in_time : using_the_persistence_engine
	{
		static readonly DateTime now = DateTime.UtcNow.AddYears(1);
		static readonly Commit first = streamId.BuildAttempt(now.AddSeconds(1));
		static readonly Commit second = first.BuildNextAttempt();
		static readonly Commit third = second.BuildNextAttempt();
		static readonly Commit fourth = third.BuildNextAttempt();
		static Commit[] committed;

		Establish context = () =>
		{
			persistence.Commit(first);
			persistence.Commit(second);
			persistence.Commit(third);
			persistence.Commit(fourth);
		};

		Because of = () =>
			committed = persistence.GetFrom(now).ToArray();

		It should_return_all_commits_on_or_after_the_point_in_time_specified = () =>
			committed.Length.ShouldEqual(4);
	}
	using System;
	using System.Linq;
	using Machine.Specifications;
	using Persistence;

  public abstract class using_the_persistence_engine
	{
		protected static readonly IPersistenceFactory Factory = new PersistenceFactoryScanner().GetFactory();
		protected static Guid streamId = Guid.NewGuid();
		protected static IPersistStreams persistence;

		Establish context = () =>
		{
			persistence = Factory.Build();
			persistence.Initialize();
		};

		Cleanup everything = () =>
		{
			persistence.Dispose();
			persistence = null;

			streamId = Guid.NewGuid();
		};
	}
}

// ReSharper enable InconsistentNaming
#pragma warning restore 169