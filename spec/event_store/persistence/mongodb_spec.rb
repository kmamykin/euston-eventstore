require_relative '../../spec_helper'

describe ::EventStore do
  describe 'mongodb persistence' do
    let(:uuid) { UUID.new }
    let(:database) { 'event_store_tests' }
    let(:config) { EventStore::Persistence::Mongodb::Config }
    let(:factory) { EventStore::Persistence::Mongodb::MongoPersistenceFactory }
    let(:stream_id) { uuid.generate }

    context 'when a commit is successfully persisted' do
      let(:now) { Time.now.utc + (60 * 60 * 24 * 7 * 52) }
      let(:attempt) { new_attempt(:commit_timestamp => now) }

      before do
        config.instance.database = database
        
        @persistence = factory.build
        @persistence.init
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
      let(:up_to_commit_with_containing_revision) { 5 }
      let(:oldest) { new_attempt }
      let(:oldest2) { next_attempt(oldest) }
      let(:oldest3) { next_attempt(oldest2) }
      let(:newest) { next_attempt(oldest3) }

      before do

      end
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
  end
end

__END__

[Subject("Persistence")]
	public class when_reading_from_a_given_revision : using_the_persistence_engine
	{
		const int LoadFromCommitContainingRevision = 3;
		const int UpToCommitWithContainingRevision = 5;
		static readonly Commit oldest = streamId.BuildAttempt(); // 2 events, revision 1-2
		static readonly Commit oldest2 = oldest.BuildNextAttempt(); // 2 events, revision 3-4
		static readonly Commit oldest3 = oldest2.BuildNextAttempt(); // 2 events, revision 5-6
		static readonly Commit newest = oldest3.BuildNextAttempt(); // 2 events, revision 7-8
		static Commit[] committed;

		Establish context = () =>
		{
			persistence.Commit(oldest);
			persistence.Commit(oldest2);
			persistence.Commit(oldest3);
			persistence.Commit(newest);
		};

		Because of = () =>
			committed = persistence.GetFrom(streamId, LoadFromCommitContainingRevision, UpToCommitWithContainingRevision).ToArray();

		It should_start_from_the_commit_which_contains_the_min_stream_revision_specified = () =>
			committed.First().CommitId.ShouldEqual(oldest2.CommitId); // contains revision 3

		It should_read_up_to_the_commit_which_contains_the_max_stream_revision_specified = () =>
			committed.Last().CommitId.ShouldEqual(oldest3.CommitId); // contains revision 5
	}

namespace EventStore.Persistence.AcceptanceTests
{
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

	[Subject("Persistence")]
	public class when_committing_a_stream_with_the_same_revision : using_the_persistence_engine
	{
		static readonly IPersistStreams persistence1 = Factory.Build();
		static readonly IPersistStreams persistence2 = Factory.Build();
		static readonly Commit attempt1 = streamId.BuildAttempt();
		static readonly Commit attempt2 = streamId.BuildAttempt();
		static Exception thrown;

		Establish context = () =>
			persistence1.Commit(attempt1);

		Because of = () =>
			thrown = Catch.Exception(() => persistence2.Commit(attempt2));

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();

		Cleanup cleanup = () =>
		{
			persistence1.Dispose();
			persistence2.Dispose();
		};
	}

	[Subject("Persistence")]
	public class when_committing_a_stream_with_the_same_sequence : using_the_persistence_engine
	{
		static readonly IPersistStreams persistence1 = Factory.Build();
		static readonly IPersistStreams persistence2 = Factory.Build();
		static readonly Commit attempt1 = streamId.BuildAttempt();
		static readonly Commit attempt2 = streamId.BuildAttempt();
		static Exception thrown;

		Establish context = () =>
			persistence1.Commit(attempt1);

		Because of = () =>
			thrown = Catch.Exception(() => persistence2.Commit(attempt2));

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();

		Cleanup cleanup = () =>
		{
			persistence1.Dispose();
			persistence2.Dispose();
		};
	}

	[Subject("Persistence")]
	public class when_attempting_to_overwrite_a_committed_sequence : using_the_persistence_engine
	{
		static readonly Commit successfulAttempt = streamId.BuildAttempt();
		static readonly Commit failedAttempt = streamId.BuildAttempt();
		static Exception thrown;

		Establish context = () =>
			persistence.Commit(successfulAttempt);

		Because of = () =>
			thrown = Catch.Exception(() => persistence.Commit(failedAttempt));

		It should_throw_a_ConcurrencyException = () =>
			thrown.ShouldBeOfType<ConcurrencyException>();
	}

	[Subject("Persistence")]
	public class when_attempting_to_persist_a_commit_twice : using_the_persistence_engine
	{
		static readonly Commit attemptTwice = streamId.BuildAttempt();
		static Exception thrown;

		Establish context = () =>
			persistence.Commit(attemptTwice);

		Because of = () =>
			thrown = Catch.Exception(() => persistence.Commit(attemptTwice));

		It should_throw_a_DuplicateCommitException = () =>
			thrown.ShouldBeOfType<DuplicateCommitException>();
	}

	[Subject("Persistence")]
	public class when_a_commit_has_been_marked_as_dispatched : using_the_persistence_engine
	{
		static readonly Commit attempt = streamId.BuildAttempt();

		Establish context = () =>
			persistence.Commit(attempt);

		Because of = () =>
			persistence.MarkCommitAsDispatched(attempt);

		It should_no_longer_be_found_in_the_set_of_undispatched_commits = () =>
			persistence.GetUndispatchedCommits().FirstOrDefault(x => x.CommitId == attempt.CommitId).ShouldBeNull();
	}

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
}

// ReSharper enable InconsistentNaming
#pragma warning restore 169