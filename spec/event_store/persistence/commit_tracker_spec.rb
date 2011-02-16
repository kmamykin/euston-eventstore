require_relative '../../spec_helper'

describe ::EventStore do
  let(:uuid) { UUID.new }

  describe 'commit tracker' do
    let(:max_commits_to_track_per_stream) { 2 }
    let(:tracker) { EventStore::Persistence::CommitTracker.new max_commits_to_track_per_stream }
    let(:stream_id) { uuid.generate }

    let(:tracked_commits) { [ commit, commit, commit ] }
    let(:untracked) { commit(:stream_id => '', :commit_id => tracked_commits.first.commit_id) }
    let(:still_tracked) { commit(:stream_id => tracked_commits.last.stream_id, :commit_id => tracked_commits.last.commit_id) }
    let(:dropped_from_tracking) { commit(:stream_id => tracked_commits.first.stream_id, :commit_id => tracked_commits.first.commit_id) }

    context 'when tracking commits' do
      before { tracked_commits.each { |c| tracker.track c } }

      it('only contains stream explicitly tracked') { tracker.contains?(untracked).should be_false }
      it('finds tracked commits') { tracker.contains?(still_tracked).should be_true }
      it('only tracks the specified number of commits') { tracker.contains?(dropped_from_tracking).should be_false }
    end

    def commit(options = {})
      defaults = { :stream_id => stream_id,
                   :stream_revision => 0,
                   :commit_id => uuid.generate,
                   :commit_sequence => 0 }

      EventStore::Commit.new(defaults.merge options)
    end
  end
end