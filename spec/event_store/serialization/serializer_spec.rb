require_relative '../../spec_helper'
require_relative './simple_message'

describe ::EventStore do
  describe 'serializer' do
    let(:serializer) { EventStore::Serialization::Mongodb::MongoSerializer.new }

    context 'when serializing a simple message' do
      let(:message) { new_simple_message }
      let(:serialized) { serializer.serialize message }
      let(:deserialized) { OpenStruct.new serializer.deserialize(serialized) }

      it('deserializes a message which contains the same id as the serialized message') { deserialized.id.should == message.id }
      it('deserializes a message which contains the same value as the serialized message') { deserialized.value.should == message.value }
      it('deserializes a message which contains the same created as the serialized message') { deserialized.created.to_f.should == message.created.to_f }
      it('deserializes a message which contains the same count as the serialized message') { deserialized.count.should == message.count }
      it('deserializes a message which contains the same contents as the serialized message') {
        deserialized.contents.should have(message.contents.length).items
        deserialized.contents.each_with_index { |c, i| c.should == message.contents[i] }
      }

      def new_simple_message
        message = EventStore::SimpleMessage.new
        message.id = UUID.new.generate
        message.count = 1234
        message.created = Time.utc(2000, 'feb', 3, 4, 5, 6, 7).to_f
        message.value = 'hello, world!'
        message.contents << 'a' << nil << '' << 'd'
        message
      end
    end

#    context 'when serializing a list of event messages' do
#      let(:messages) { [ new_message('some value'), new_message(42), new_message(EventStore::SimpleMessage.new) ] }
#      let(:serialized) { serializer.serialize messages }
#      let(:deserialized) { serializer.deserialize serialized }
#
#      it('deserializes the same number of event messages as it serialized') { deserialized.should have(messages.length).items }
#
#      def new_message(body)
#        EventStore::EventMessage.new body
#      end
#    end
  end
end

__END__

	[Subject("Serialization")]
	public class when_serializing_a_list_of_event_messages : using_serialization
	{
		private static readonly List<EventMessage> Messages = new List<EventMessage>
		{
			new EventMessage { Body = "some value" },
			new EventMessage { Body = 42 },
			new EventMessage { Body = new SimpleMessage() }
		};
		static byte[] serialized;
		static List<EventMessage> deserialized;

		Establish context = () =>
			serialized = Serializer.Serialize(Messages);

		Because of = () =>
			deserialized = Serializer.Deserialize<List<EventMessage>>(serialized);

		It should_deserialize_the_same_number_of_event_messages_as_it_serialized = () =>
			Messages.Count.ShouldEqual(deserialized.Count);

		It should_deserialize_the_the_complex_types_within_the_event_messages = () =>
			deserialized.Last().Body.ShouldBeOfType<SimpleMessage>();
	}

	[Subject("Serialization")]
	public class when_serializing_a_list_of_commit_headers : using_serialization
	{
		private static readonly Dictionary<string, object> Headers = new Dictionary<string, object>
		{
			{ "HeaderKey", "SomeValue" },
			{ "AnotherKey", 42 },
			{ "AndAnotherKey", Guid.NewGuid() },
			{ "LastKey", new SimpleMessage() }
		};
		static byte[] serialized;
		static Dictionary<string, object> deserialized;

		Establish context = () =>
			serialized = Serializer.Serialize(Headers);

		Because of = () =>
			deserialized = Serializer.Deserialize<Dictionary<string, object>>(serialized);

		It should_deserialize_the_same_number_of_event_messages_as_it_serialized = () =>
			Headers.Count.ShouldEqual(deserialized.Count);

		It should_deserialize_the_the_complex_types_within_the_event_messages = () =>
			deserialized.Last().Value.ShouldBeOfType<SimpleMessage>();
	}

	[Subject("Serialization")]
	public class when_serializing_a_commit_message : using_serialization
	{
		static readonly Commit Message = Guid.NewGuid().BuildCommit();
		static byte[] serialized;
		static Commit deserialized;

		Establish context = () =>
			serialized = Serializer.Serialize(Message);

		Because of = () =>
			deserialized = Serializer.Deserialize<Commit>(serialized);

		It should_deserialize_a_commit_which_contains_the_same_StreamId_as_the_serialized_commit = () =>
			deserialized.StreamId.ShouldEqual(Message.StreamId);

		It should_deserialize_a_commit_which_contains_the_same_CommitId_as_the_serialized_commit = () =>
			deserialized.CommitId.ShouldEqual(Message.CommitId);

		It should_deserialize_a_commit_which_contains_the_same_StreamRevision_as_the_serialized_commit = () =>
			deserialized.StreamRevision.ShouldEqual(Message.StreamRevision);

		It should_deserialize_a_commit_which_contains_the_same_CommitSequence_as_the_serialized_commit = () =>
			deserialized.CommitSequence.ShouldEqual(Message.CommitSequence);

		It should_deserialize_a_commit_which_contains_the_same_number_of_headers_as_the_serialized_commit = () =>
			deserialized.Headers.Count.ShouldEqual(Message.Headers.Count);

		It should_deserialize_a_commit_which_contains_the_same_headers_as_the_serialized_commit = () =>
		{
			foreach (var header in deserialized.Headers)
				header.Value.ShouldEqual(Message.Headers[header.Key]);

			deserialized.Headers.Values.SequenceEqual(Message.Headers.Values);
		};

		It should_deserialize_a_commit_which_contains_the_same_number_of_events_as_the_serialized_commit = () =>
			deserialized.Events.Count.ShouldEqual(Message.Events.Count);
	}

	public abstract class using_serialization
	{
		protected static readonly ISerialize Serializer = new SerializationFactory().Build();
	}