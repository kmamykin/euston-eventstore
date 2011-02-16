require_relative '../../spec_helper'

describe ::EventStore do
  let(:uuid) { UUID.new }

  describe 'commit filter persistence' do
    let(:stream_id) { uuid.generate }
    let(:fake_persistence) { double('persistence').as_null_object }
    let(:filter_persistence) { EventStore::Persistence::CommitFilterPersistence.new fake_persistence }

    after { stream_id = uuid.generate }

    context 'when initializing storage' do
      before do
        fake_persistence.stub(:init) { @initialized = true }
        filter_persistence.init
      end

      it('calls the underlying persistence infrastructure') { @initialized.should be_true }
    end

    context 'when reading commits for a given stream' do
      let(:min_revision) { 42 }
      let(:max_revision) { 43 }
      let(:commits) { [ commit(:stream_revision => 0, :commit_sequence => 0), commit(:stream_revision => 0, :commit_sequence => 0) ] }
      let(:read_filter) { double('read filter').as_null_object }
      let(:filter_persistence) { EventStore::Persistence::CommitFilterPersistence.new fake_persistence, [ read_filter ] }

      before do
        fake_persistence.stub(:get_from).with(:stream_id => stream_id, :min_revision => min_revision, :max_revision => max_revision) { @invoked = true; commits }
        read_filter.stub(:filter_read).with(commits.first) { @read_1 = true; commits.first }
        read_filter.stub(:filter_read).with(commits.last) { @read_2 = true; nil }
        @read = filter_persistence.get_from :stream_id => stream_id, :min_revision => min_revision, :max_revision => max_revision
      end

      it('calls the underlying persistence infrastructure') { @invoked.should be_true }
      it('passes the commits through the filter') {
        @read_1.should be_true
        @read_2.should be_true
      }
      it('only returns non-null filtered commits') { @read.should have(1).items }
    end

    context 'when persisting an attempt' do
      let(:attempt) { commit }
      let(:filtered) { commit }
      let(:write_filter) { double('write filter').as_null_object }
      let(:filter_persistence) { EventStore::Persistence::CommitFilterPersistence.new fake_persistence, nil, [ write_filter ] }

      before do
        write_filter.stub(:filter_write).with(attempt) { filtered }
        fake_persistence.stub(:commit).with(filtered) { @invoked = true }
        filter_persistence.commit attempt
      end

      it('provides the filtered attempt to the persistence infrastructure') { @invoked.should be_true }
    end

    context 'when retrieving undispatched commits' do
      before do
        fake_persistence.stub(:get_undispatched_commits) { @invoked = true }
        filter_persistence.get_undispatched_commits
      end

      it('calls the underlying persistence infrastructure') { @invoked.should be_true }
    end

    context 'when marking a commit as dispatched' do
      let(:dispatched) { commit(:stream_revision => 0, :commit_sequence => 0) }

      before do
        fake_persistence.stub(:mark_commit_as_dispatched).with(dispatched) { @invoked = true }
        filter_persistence.mark_commit_as_dispatched dispatched
      end

      it('calls the underlying persistence infrastructure') { @invoked.should be_true }
    end

    context 'when retrieving a list of streams to snapshot' do
      let(:threshold) { 10 }

      before do
        fake_persistence.stub(:get_streams_to_snapshot).with(threshold) { @invoked = true }
        filter_persistence.get_streams_to_snapshot threshold
      end

      it('calls the underlying persistence infrastructure') { @invoked.should be_true }
    end

    context 'when adding a snapshot' do
      let(:snapshot) { EventStore::Snapshot.new stream_id, 0, 1 }

      before do
        fake_persistence.stub(:add_snapshot).with(snapshot) { @invoked = true }
        filter_persistence.add_snapshot snapshot
      end

      it('calls the underlying persistence framework') { @invoked = true }
    end

    def commit(options = {})
      defaults = { :stream_id => stream_id,
                   :stream_revision => 1,
                   :commit_id => uuid.generate,
                   :commit_sequence => 1 }

      EventStore::Commit.new(defaults.merge options)
    end
  end
end