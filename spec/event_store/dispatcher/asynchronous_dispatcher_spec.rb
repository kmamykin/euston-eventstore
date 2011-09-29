describe Euston::EventStore do
  let(:uuid) { Uuid }

  describe 'asynchronous dispatcher' do
    context 'when instantiating the asynchronous dispatcher' do
      let(:stream_id) { uuid.generate }
      let(:commits) { [ new_commit(:stream_id => stream_id), new_commit(:stream_id => stream_id) ] }
      let(:bus) { stub('bus').as_null_object }
      let(:persistence) { stub('persistence').as_null_object }

      before do
        persistence.should_receive(:init).once
        persistence.should_receive(:get_undispatched_commits).once { commits }
        bus.should_receive(:publish).with(commits.first).once
        bus.should_receive(:publish).with(commits.last).once

        Euston::EventStore::Dispatcher::AsynchronousDispatcher.new bus, persistence
        sleep 0.25
      end

      it('initializes the persistence engine') { persistence.rspec_verify }
      it('gets the set of undispatched commits') { persistence.rspec_verify }
      it('provides the commits to the published') { bus.rspec_verify }
    end

    context 'when asynchronously dispatching a commit' do
      let(:commit) { new_commit }
      let(:bus) { stub('bus').as_null_object }
      let(:persistence) { stub('persistence').as_null_object }

      before do
        bus.should_receive(:publish).with(commit).once
        persistence.should_receive(:mark_commit_as_dispatched).with(commit).once

        @dispatcher = Euston::EventStore::Dispatcher::AsynchronousDispatcher.new bus, persistence
        @dispatcher.dispatch commit
        sleep 0.25
      end

      it('provides the commit to the message bus') { bus.rspec_verify }
      it('marks the commit as dispatched') { persistence.rspec_verify }
    end

    context 'when an asynchronously dispatched commit throws an exception' do
      let(:commit) { new_commit }
      let(:persistence) { stub('persistence').as_null_object }

      before do
        persistence.stub(:get_undispatched_commits) { [] }

        @dispatcher = Euston::EventStore::Dispatcher::AsynchronousDispatcher.new nil, persistence do |commit, exception|
          @caught_commit = commit
          @caught_exception = exception
        end

        @dispatcher.dispatch commit
        sleep 0.25
      end

      it('provides the commit that caused the error') { @caught_commit.should be_an(Euston::EventStore::Commit) }
      it('provides the exception') { @caught_exception.should be_an(Exception) }
    end

    def new_commit(options = {})
      defaults = { :stream_id => uuid.generate,
                   :stream_revision => 0,
                   :commit_id => uuid.generate,
                   :commit_sequence => 0 }

      Euston::EventStore::Commit.new(defaults.merge options)
    end
  end
end
