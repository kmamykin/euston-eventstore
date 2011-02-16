require_relative '../../spec_helper'

describe ::EventStore do
  describe 'synchronous dispatcher' do
    let(:bus) { stub('bus').as_null_object }
    let(:persistence) { stub('persistence').as_null_object }

    context 'when instantiating' do
      let(:commits) { [ new_commit, new_commit ] }

      before do
        persistence.should_receive(:init).once
        persistence.should_receive(:get_undispatched_commits).once { commits }
        bus.should_receive(:publish).with(commits.first).once
        bus.should_receive(:publish).with(commits.last).once

        EventStore::Dispatcher::SynchronousDispatcher.new bus, persistence
      end

      it('initializes the persistence engine') { persistence.rspec_verify }
      it('gets the set of undispatched commits') { persistence.rspec_verify }
      it('provides the commits to the publisher') { bus.rspec_verify }
    end

    context 'when synchronously dispatching a commit' do
      let(:commit) { new_commit }

      before do
        persistence.stub(:get_undispatched_commits) { [] }
        persistence.should_receive(:mark_commit_as_dispatched).with(commit).once
        bus.should_receive(:publish).with(commit).once

        @dispatcher = EventStore::Dispatcher::SynchronousDispatcher.new bus, persistence
        @dispatcher.dispatch commit
      end

      it('provides the commit to the message bus') { bus.rspec_verify }
      it('marks the commit as dispatched') { persistence.rspec_verify }
    end

    def new_commit(options = {})
      defaults = { :stream_id => UUID.new,
                   :stream_revision => 0,
                   :commit_id => UUID.new,
                   :commit_sequence => 0 }

      EventStore::Commit.new(defaults.merge options)
    end
  end
end
