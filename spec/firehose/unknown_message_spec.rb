require_relative 'ex_invalid_message'

describe Skyfall::Firehose::UnknownMessage do
  let(:cbor) { cbor_sequence(*data) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#hellthread' },
    { 'level' => 9001 }
  ]}

  include_examples "invalid firehose message"

  context 'with valid data' do
    it 'should parse an unknown message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::UnknownMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.should be_unknown
    end

    it 'should expose the included message type' do
      message = build_message(cbor)

      message.type.should == :hellthread
      message.kind.should == :hellthread
    end

    it 'should have did, repo, seq & time properties which return nil' do
      message = build_message(cbor)

      message.repo.should be_nil
      message.did.should be_nil
      message.seq.should be_nil
      message.time.should be_nil
    end

    it 'should have an operations field that returns []' do
      message = build_message(cbor)
      message.operations.should == []
    end
  end
end
