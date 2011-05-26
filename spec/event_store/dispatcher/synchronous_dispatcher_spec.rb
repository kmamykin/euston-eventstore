require_relative '../../spec_helper'

describe ::EventStore do
  let(:uuid) { UUID.new }

  describe 'synchronous dispatcher' do
    let(:bus) { stub('bus').as_null_object }
    let(:persistence) { stub('persistence').as_null_object }

    context 'when synchronously dispatching a commit' do
      let(:commit) { new_commit }

      before do
        persistence.stub(:get_undispatched_commits) { [] }
        persistence.should_receive(:mark_commit_as_dispatched).with(commit).once
        
        @dispatched_commits = []

        @dispatcher = EventStore::Dispatcher::SynchronousDispatcher.new(persistence) do |c|
          @dispatched_commits << c
        end

        @dispatcher.dispatch commit
      end

      it('provides the commit to the message bus') { @dispatched_commits.should have(1).item }
      it('marks the commit as dispatched') { persistence.rspec_verify }
    end

    def new_commit(options = {})
      defaults = { :stream_id => uuid.generate,
                   :stream_revision => 0,
                   :commit_id => uuid.generate,
                   :commit_sequence => 0 }

      EventStore::Commit.new(defaults.merge options)
    end
  end
end
