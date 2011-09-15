require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe Euston::EventStore do
  describe 'mongodb persistence' do
    let(:uuid) { Uuid }
    let(:database) { 'event_store_tests' }
    let(:config) { Euston::EventStore::Persistence::Mongodb::Config }
    let(:factory) { Euston::EventStore::Persistence::Mongodb::MongoPersistenceFactory }
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
                                           :max_revision => Euston::EventStore::FIXNUM_MAX).first
      end

      it('correctly persists the stream identifier') { @persisted.stream_id.should == attempt.stream_id }
      it('correctly persists the stream revision') { @persisted.stream_revision.should == attempt.stream_revision }
      it('correctly persists the commit identifier') { @persisted.commit_id.should == attempt.commit_id }
      it('correctly persists the commit sequence') { @persisted.commit_sequence.should == attempt.commit_sequence }

		  # persistence engines have varying levels of precision with respect to time.
		  it('correctly persists the commit timestamp') { (@persisted.commit_timestamp - now.to_f).should be <= 1 }

      it('correctly persists the headers') { @persisted.headers.should have(attempt.headers.length).items }
      it('correctly persists the events') { @persisted.events.should have(attempt.events.length).items }
      it('makes the commit available to be read from the stream') {
        @persistence.get_from(:stream_id => stream_id,
                              :min_revision => 0,
                              :max_revision => Euston::EventStore::FIXNUM_MAX).first.commit_id.should == attempt.commit_id }

      it('adds the commit to the set of undispatched commits') {
			  @persistence.get_undispatched_commits.detect { |x| x.commit_id == attempt.commit_id }.should_not be_nil }

      it('causes the stream to be found in the list of streams to snapshot') {
        @persistence.get_streams_to_snapshot(1).detect { |x| x.stream_id == stream_id }.should_not be_nil }
    end

    context 'when reading from a given revision' do
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

      it('raises a ConcurrencyError') { @caught.should be_an(Euston::EventStore::ConcurrencyError) }
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

      it('raises a ConcurrencyError') { @caught.should be_an(Euston::EventStore::ConcurrencyError) }
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

      it('raises a ConcurrencyError') { @caught.should be_an(Euston::EventStore::ConcurrencyError) }
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

      it('raises a DuplicateCommitError') { @caught.should be_an(Euston::EventStore::DuplicateCommitError) }
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

    context 'when saving a snapshot' do
      let(:snapshot) { Euston::EventStore::Snapshot.new stream_id, 1, { :key => :value } }

      before do
        @persistence.commit new_attempt

        sleep 0.25

        @added = @persistence.add_snapshot snapshot
      end

      it('indicates the snapshot was added') { @added.should be_true }
      it('is able to retrieve the snapshot') { @persistence.get_snapshot(stream_id, snapshot.stream_revision).should_not be_nil }
    end

    context 'when retrieving a snapshot' do
      let(:too_far_back) { Euston::EventStore::Snapshot.new stream_id, 1, {} }
      let(:correct) { Euston::EventStore::Snapshot.new stream_id, 3, { 'key' => 'value' } }
      let(:too_far_forward) { Euston::EventStore::Snapshot.new stream_id, 5, {} }
      let(:commit1) { new_attempt }
      let(:commit2) { next_attempt commit1 }
      let(:commit3) { next_attempt commit2 }

      before do
        @persistence.commit commit1
        @persistence.commit commit2
        @persistence.commit commit3

        sleep 0.25

        @persistence.add_snapshot too_far_back
        @persistence.add_snapshot correct
        @persistence.add_snapshot too_far_forward

        @snapshot = @persistence.get_snapshot stream_id, too_far_forward.stream_revision - 1
      end

      it('loads the most recent prior snapshot') { @snapshot.stream_revision.should == correct.stream_revision }
      it('has the correct snapshot payload') { @snapshot.payload.should == correct.payload }
    end

    context 'when a snapshot has been added to the most recent commit of a stream' do
      let(:oldest) { new_attempt }
      let(:oldest2) { next_attempt oldest }
      let(:newest) { next_attempt oldest2 }
      let(:snapshot) { Euston::EventStore::Snapshot.new stream_id, newest.stream_revision, { :key => :value } }

      before do
        @persistence.commit oldest
        @persistence.commit oldest2
        @persistence.commit newest

        sleep 0.25

        @persistence.add_snapshot snapshot
      end

      it('no longer finds the stream in the set of streams to be snapshot') {
        @persistence.get_streams_to_snapshot(1).detect { |x| x.stream_id == stream_id }.should be_nil }
    end

# Timing issues with this one?
#
#    context 'when adding a commit after a snapshot' do
#      let(:within_threshold) { 2 }
#      let(:over_threshold) { 3 }
#      let(:snapshot_data) { { :key => :value } }
#      let(:oldest) { new_attempt }
#      let(:oldest2) { next_attempt oldest }
#      let(:newest) { next_attempt oldest2 }

#      before do
#        @persistence.commit oldest
#        @persistence.commit oldest2

#        sleep 0.25

#        @persistence.add_snapshot Euston::EventStore::Snapshot.new(stream_id, oldest2.stream_revision, snapshot_data)
#        @persistence.commit newest
#      end

#      it 'finds the stream in the set of streams to be snapshot when within the threshold' do
#        @persistence.get_streams_to_snapshot(within_threshold).detect { |x| x.stream_id == stream_id }.should_not be_nil
#      end

#      it 'does not find the stream in the set of stream to be snapshot when over the threshold' do
#        @persistence.get_streams_to_snapshot(over_threshold).detect { |x| x.stream_id == stream_id }.should be_nil
#      end
#    end

    context 'when reading all commits from a particular point in time' do
      let(:now) { Time.now.utc + (60 * 60 * 24 * 7 * 52) }
      let(:first) { new_attempt(:commit_timestamp => now + 1) }
      let(:second) { next_attempt first }
      let(:third) { next_attempt second }
      let(:fourth) { next_attempt third }

      before do
        @persistence.commit first
        @persistence.commit second
        @persistence.commit third
        @persistence.commit fourth

        @committed = @persistence.get_from :timestamp => now
      end

      it('returns all commits on or after the point in time specified') { @committed.should have(4).items }
    end

    def new_attempt(options = {})
      defaults = { :stream_id => stream_id,
                   :stream_revision => 2,
                   :commit_id => uuid.generate,
                   :commit_sequence => 1,
                   :commit_timestamp => Time.now.utc,
                   :headers => { 'A header' => 'A string value',
                                 'Another header' => 2 },
                   :events => [ Euston::EventStore::EventMessage.new(:some_property => 'test'),
                                Euston::EventStore::EventMessage.new(:some_property => 'test2') ] }

      Euston::EventStore::Commit.new(defaults.merge options)
    end

    def next_attempt(attempt)
      Euston::EventStore::Commit.new(:stream_id => attempt.stream_id,
                                     :stream_revision => attempt.stream_revision + 2,
                                     :commit_id => uuid.generate,
                                     :commit_sequence => attempt.commit_sequence + 1,
                                     :commit_timestamp => attempt.commit_timestamp,
                                     :headers => {},
                                     :events => [ Euston::EventStore::EventMessage.new(:some_property => 'Another test'),
                                                  Euston::EventStore::EventMessage.new(:some_property => 'Another test2') ])
    end
  end
end
