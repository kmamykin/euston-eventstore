require_relative '../../spec_helper'

describe ::EventStore do
  describe 'asynchronous dispatcher' do
    context 'when instantiating the asynchronous dispatcher' do
      let(:stream_id) { UUID.new }
      let(:commits) { [
        EventStore::Commit.new(:stream_id => stream_id, :stream_revision => 0, :commit_sequence => 0),
        EventStore::Commit.new(:stream_id => stream_id, :stream_revision => 0, :commit_sequence => 0) ] }
      let(:bus) { double('bus').as_null_object }
      let(:persistence) { double('persistence').as_null_object }

      before do
        persistence.stub(:init) { @persistence_initialized = true }
        persistence.stub(:get_undispatched_commits) { @undispatched_commits_loaded = true; commits }
        bus.stub(:publish).with(commits.first) { @published_first = true }
        bus.stub(:publish).with(commits.last) { @published_last = true }

        AsynchronousDispatcher.new bus, persistence, nil
      end

      it('takes a few milliseconds for the other thread to execute') { }
      it('initializes the persistence engine') { @persistence_initialized.should be_true }
      it('gets the set of undispatched commits') { @undispatched_commits_loaded.should be_true }
      it('provides the commits to the published') {
        @published_first.should be_true
        @published_last.should be_true
      }
    end
  end
end

__END__

[Subject("AsynchronousDispatcher")]
	public class when_instantiaing_the_asynchronous_dispatcher
	{
		static readonly Guid streamId = Guid.NewGuid();
		private static readonly Commit[] commits =
		{
			new Commit(streamId, 0, Guid.NewGuid(), 0, DateTime.UtcNow, null, null),
			new Commit(streamId, 0, Guid.NewGuid(), 0, DateTime.UtcNow, null, null)
		};
		static readonly Mock<IPublishMessages> bus = new Mock<IPublishMessages>();
		static readonly Mock<IPersistStreams> persistence = new Mock<IPersistStreams>();

		Establish context = () =>
		{
			persistence.Setup(x => x.Initialize());
			persistence.Setup(x => x.GetUndispatchedCommits()).Returns(commits);
			bus.Setup(x => x.Publish(commits.First()));
			bus.Setup(x => x.Publish(commits.Last()));
		};

		Because of = () =>
			new AsynchronousDispatcher(bus.Object, persistence.Object, null);

		It should_take_a_few_milliseconds_for_the_other_thread_to_execute = () =>
			Thread.Sleep(25); // just a precaution because we're doing async tests

		It should_initialize_the_persistence_engine = () =>
			persistence.Verify(x => x.Initialize(), Times.Once());

		It should_get_the_set_of_undispatched_commits = () =>
			persistence.Verify(x => x.GetUndispatchedCommits(), Times.Once());

		It should_provide_the_commits_to_the_publisher = () =>
			bus.VerifyAll();
	}

	[Subject("AsynchronousDispatcher")]
	public class when_asynchronously_dispatching_a_commit
	{
		static readonly Commit commit = new Commit(Guid.NewGuid(), 0, Guid.NewGuid(), 0, DateTime.UtcNow, null, null);
		static readonly Mock<IPublishMessages> bus = new Mock<IPublishMessages>();
		static readonly Mock<IPersistStreams> persistence = new Mock<IPersistStreams>();
		static AsynchronousDispatcher dispatcher;

		Establish context = () =>
		{
			bus.Setup(x => x.Publish(commit));
			persistence.Setup(x => x.MarkCommitAsDispatched(commit));

			dispatcher = new AsynchronousDispatcher(bus.Object, persistence.Object, null);
		};

		Because of = () =>
			dispatcher.Dispatch(commit);

		It should_take_a_few_milliseconds_for_the_other_thread_to_execute = () =>
			Thread.Sleep(25); // just a precaution because we're doing async tests

		It should_provide_the_commit_to_the_message_bus = () =>
			bus.Verify(x => x.Publish(commit), Times.Once());

		It should_mark_the_commit_as_dispatched = () =>
			persistence.Verify(x => x.MarkCommitAsDispatched(commit), Times.Once());
	}

	[Subject("AsynchronousDispatcher")]
	public class when_an_asynchronously_dispatch_commit_throws_an_exception
	{
		static readonly Commit commit = new Commit(Guid.NewGuid(), 0, Guid.NewGuid(), 0, DateTime.UtcNow, null, null);

		static AsynchronousDispatcher dispatcher;

		static Exception thrown;
		static Commit handedBack;

		Establish context = () =>
		{
			dispatcher = new AsynchronousDispatcher(
				null, // we want a NullReferenceException to be thrown
				new Mock<IPersistStreams>().Object,
				(c, e) =>
				{
					handedBack = c;
					thrown = e;
				});
		};

		Because of = () =>
			dispatcher.Dispatch(commit);

		It should_take_a_few_milliseconds_for_the_other_thread_to_execute = () =>
			Thread.Sleep(25); // just a precaution because we're doing async tests

		It should_handed_back_the_commit_that_caused_the_exception = () =>
			handedBack.ShouldEqual(commit);

		It should_provide_the_exception_that_indicates_the_problem = () =>
			thrown.ShouldNotBeNull();
	}

	[Subject("AsynchronousDispatcher")]
	public class when_disposing_the_async_dispatcher
	{
		static readonly Mock<IPublishMessages> bus = new Mock<IPublishMessages>();
		static readonly Mock<IPersistStreams> persistence = new Mock<IPersistStreams>();
		static AsynchronousDispatcher dispatcher;

		Establish context = () =>
		{
			bus.Setup(x => x.Dispose());
			persistence.Setup(x => x.Dispose());
			dispatcher = new AsynchronousDispatcher(bus.Object, persistence.Object, null);
		};

		Because of = () =>
		{
			dispatcher.Dispose();
			dispatcher.Dispose();
		};

		It should_dispose_the_underlying_message_bus_exactly_once = () =>
			bus.Verify(x => x.Dispose(), Times.Once());

		It should_dispose_the_underlying_persistence_infrastructure_exactly_once = () =>
			bus.Verify(x => x.Dispose(), Times.Once());
	}