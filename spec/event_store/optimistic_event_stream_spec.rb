require_relative '../spec_helper'

describe ::EventStore do
  let(:uuid) { UUID.new }
  let(:default_stream_revision) { 1 }
  let(:default_commit_sequence) { 1 }
  let(:stream_id) { uuid.generate }
  let(:persistence) { double('persistence') }
  let(:stream) { EventStore::OptimisticEventStream.new(:stream_id => stream_id, :persistence => persistence) }

  after { stream_id = uuid.generate }

  def build_commit_stub(stream_id, revision, sequence, length)
    ::EventStore::Commit.new( :stream_id => stream_id,
                              :stream_revision => revision,
                              :commit_sequence => sequence,
                              :events => length.times.map{ ::EventStore::EventMessage.new })
  end

  describe 'optimistic event stream' do
    context 'when constructing a new stream' do
      let(:min_revision) { 2 }
      let(:max_revision) { 7 }
      let(:commit_length) { 2 }
      let(:committed) { [
          build_commit_stub(stream_id, 2, 1, commit_length),
          build_commit_stub(stream_id, 4, 2, commit_length),
          build_commit_stub(stream_id, 6, 3, commit_length),
          build_commit_stub(stream_id, 8, 3, commit_length)
      ] }

      before do
        persistence.stub(:get_from).with(stream_id, min_revision, max_revision) { committed }
        @stream = EventStore::OptimisticEventStream.new(:stream_id => stream_id,
                                                        :persistence => persistence,
                                                        :min_revision => min_revision,
                                                        :max_revision => max_revision)
      end

      it 'has the correct stream identifier' do
        @stream.stream_id.should == stream_id
      end

      it 'has the correct head stream revision' do
        @stream.stream_revision.should == max_revision
      end

      it 'has the correct head commit sequence' do
        @stream.commit_sequence.should == committed.last.commit_sequence
      end

      it 'does not include the event below the minimum revision indicated' do
        @stream.committed_events.first.should == committed.first.events.last
      end

      it 'does not include events above the maximum revision indicated' do
        @stream.committed_events.last.should == committed.last.events.first
      end

      it 'has all of the committed events up to the stream revision specified' do
        @stream.committed_events.length.should == max_revision - min_revision + 1
      end
    end

    context 'when constructing the head event revision is less than the max desired revision' do
      let(:commit_length) { 2 }
      let(:committed) { [
          build_commit_stub(stream_id, 2, 1, commit_length),
          build_commit_stub(stream_id, 4, 2, commit_length),
          build_commit_stub(stream_id, 6, 3, commit_length),
          build_commit_stub(stream_id, 8, 3, commit_length)
      ] }

      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { committed }
        @stream = EventStore::OptimisticEventStream.new(:stream_id => stream_id,
                                                        :persistence => persistence,
                                                        :min_revision => 0,
                                                        :max_revision => EventStore::FIXNUM_MAX)
      end

      it 'sets the stream revision to the revision of the most recent event' do
        @stream.stream_revision.should == committed.last.stream_revision
      end
    end

    context 'when adding a null event message' do
      before do 
        stream << nil
      end

      it 'is ignored' do
        stream.uncommitted_events.should be_empty
      end
    end

    context 'when adding an unpopulated event message' do
      before do 
        stream << EventStore::EventMessage.new(nil)
      end

      it 'is ignored' do 
        stream.uncommitted_events.should be_empty
      end
    end

    context 'when adding a fully populated event message' do
      before do 
        stream << EventStore::EventMessage.new('populated')
      end

      it 'adds the event to the set of uncommitted events' do
        stream.uncommitted_events.should have(1).items
      end
    end

    context 'when adding multiple populated event messages' do
      before do
        stream << EventStore::EventMessage.new('populated')
        stream << EventStore::EventMessage.new('also populated')
      end

      it 'adds all the events provided to the set of uncommitted events' do
        stream.uncommitted_events.should have(2).items
      end
    end

    context 'when adding a simple object as an event message' do
      let(:my_event) { 'some event data' }

      before do
        stream << EventStore::EventMessage.new(my_event)
      end

      it 'adds the uncommitted event to the set of uncommitted events' do
        stream.uncommitted_events.should have(1).items
      end

      it 'wraps the uncommitted event in an EventMessage object' do
        stream.uncommitted_events.first.body.should == my_event
      end
    end

    context 'when clearing any uncommitted changes' do
      before do
        stream << EventStore::EventMessage.new('')
        stream.clear_changes
      end

      it 'clears all uncommitted events' do
        stream.uncommitted_events.should be_empty
      end
    end

    context 'when committing an empty changeset' do
      before do
        persistence.stub(:commit) { @persisted = true }
        stream.commit_changes uuid.generate
      end

      it 'does not call the underlying infrastructure' do
        @persisted.should be_nil
      end

      it 'does not increment the current stream revision' do
        stream.stream_revision.should == 0
      end

      it 'does not increment the current commit sequence' do
        stream.commit_sequence.should == 0
      end
    end

    context 'when committing any uncommitted changes' do
      let(:commit_id) { uuid.generate }
      let(:uncommitted) { EventStore::EventMessage.new '' }
      let(:headers) { { :key => :value } }

      before do
        persistence.stub(:commit) { |c| @constructed = c }
        stream << uncommitted
        headers.each { |key, value| stream.uncommitted_headers[key] = value }        
        stream.commit_changes commit_id
      end

      it 'provides a commit to the underlying infrastructure' do
        @constructed.should_not be_nil
      end

      it 'builds the commit with the correct stream identifier' do
        @constructed.stream_id.should == stream_id
      end

      it 'builds the commit with the correct stream revision' do
        @constructed.stream_revision.should == default_stream_revision
      end

      it 'builds the commit with the correct commit identifier' do
        @constructed.commit_id.should == commit_id
      end

      it 'builds the commit with an incremented commit sequence' do
        @constructed.commit_sequence.should == default_commit_sequence
      end

      it 'builds the commit with the correct commit stamp' do
        ((Time.now - @constructed.commit_timestamp) < 0.05).should be_true
      end

      it 'builds the commit with the headers provided' do
        @constructed.headers.each do |key, value|
          headers[key].should == value
        end
        @constructed.headers.keys.length.should == headers.keys.length
      end

    	it 'builds the commit containing all uncommitted events' do
    		@constructed.events.should have(1).items
  		end

    	it 'builds the commit using the event messages provided' do
    		@constructed.events.first.should == uncommitted
  		end

    	it 'updates the stream revision' do
    		stream.stream_revision.should == @constructed.stream_revision
  		end

    	it 'updates the commit sequence' do
    		stream.commit_sequence.should == @constructed.commit_sequence
  		end

    	it 'adds the uncommitted events to the committed events' do
    		stream.committed_events.last.should == uncommitted
  		end

    	it 'clears the uncommitted events' do
    		stream.uncommitted_events.should have(0).items
  		end

    	it 'clears the uncommitted headers' do
    		stream.uncommitted_headers.should have(0).items
  		end
    end

    context 'when committing with an identifier that was previously read' do
    	let(:committed) { [ build_commit_stub(stream_id, 1, 1, 1) ] }
      let(:duplicate_commit_id) { committed.first.commit_id }
      
      before do
        persistence.stub(:get_from).with(stream_id, 0, EventStore::FIXNUM_MAX) { committed }

        @stream = EventStore::OptimisticEventStream.new(:stream_id => stream_id,
                                                        :persistence => persistence,
                                                        :min_revision => 0,
                                                        :max_revision => EventStore::FIXNUM_MAX)

        begin
          @stream.commit_changes duplicate_commit_id
        rescue Exception => e
          @thrown = e
        end
      end

    	it 'throws a DuplicateCommitError' do
    		@thrown.should be_a(EventStore::DuplicateCommitError)
  		end
    end

    context 'when committing after another thread or process has moved the stream head' do
      let(:stream_revision) { 1 }
    	let(:committed) { [ build_commit_stub(stream_id, 1, 1, 1) ] }
    	let(:uncommitted) { EventStore::EventMessage.new ''  }
    	let(:discovered_on_commit) { [ build_commit_stub(stream_id, 3, 2, 2) ] }

      before do
        persistence.stub(:commit) { raise EventStore::ConcurrencyError.new }
    		persistence.stub(:get_from).with(stream_id, stream_revision, EventStore::FIXNUM_MAX) { committed }
    		persistence.stub(:get_from).with(stream_id, stream_revision + 1, EventStore::FIXNUM_MAX) do 
    		  @queried_for_new_commits = true
          discovered_on_commit
        end

    		@stream = EventStore::OptimisticEventStream.new(:stream_id => stream_id,
                                                        :persistence => persistence,
                                                        :min_revision => stream_revision,
                                                        :max_revision => EventStore::FIXNUM_MAX)
    		@stream << uncommitted

        begin
          @stream.commit_changes uuid.generate
        rescue Exception => e
          @thrown = e
        end
      end

    	it 'throws a ConcurrencyError' do
    		@thrown.should be_a(EventStore::ConcurrencyError)
  		end

    	it 'queries the underlying storage to discover the new commits' do
    		@queried_for_new_commits.should be_true
  		end

    	it 'updates the stream revision accordingly' do
    		@stream.stream_revision.should == discovered_on_commit.first.stream_revision
  		end

    	it 'updates the commit sequence accordingly' do
    		@stream.commit_sequence.should == discovered_on_commit.first.commit_sequence
  		end

    	it 'add the newly discovered committed events to the set of committed events accordingly' do
    		@stream.committed_events.should have(discovered_on_commit.first.events.length + 1).items
  		end
    end
  end
end
