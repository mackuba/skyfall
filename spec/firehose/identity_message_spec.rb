require_relative 'ex_invalid_message'

describe Skyfall::Firehose::IdentityMessage do
  let(:cbor) { cbor_sequence(*data) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#identity' },
    {
      'seq' => 3333,
      'did' => 'did:plc:foobar',
      'time' => '2025-02-01T00:00:00Z',
      'handle' => 'alice.test'
    }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(seq did time).each do |field|
      it "should throw an error if #{field} is missing" do
        data[1].delete(field)

        expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError)
      end

      it "should throw an error if #{field} is nil" do
        data[1][field] = nil

        expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError)
      end
    end
  end

  context 'with valid data' do
    it 'should parse an identity message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::IdentityMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :identity
      message.kind.should == :identity
      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'
      message.seq.should == 3333
      message.should_not be_unknown
    end

    it 'should parse the timestamp' do
      message = build_message(cbor)
      message.time.should == Time.parse('2025-02-01T00:00:00Z')
    end

    it 'should work when created using the IdentityMessage constructor' do
      message = Skyfall::Firehose::IdentityMessage.new(cbor)
      message.should be_a(Skyfall::Firehose::IdentityMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Firehose::AccountMessage.new(cbor) }.to raise_error(Skyfall::DecodeError)
    end

    it 'should have an operations field that returns []' do
      message = build_message(cbor)
      message.operations.should == []
      message.ops.should == []
    end
  end

  describe '#handle' do
    context 'with nil handle' do
      before do
        data[1].delete('handle')
      end

      it 'should return nil' do
        message = build_message(cbor)
        message.handle.should be_nil
      end
    end

    context 'with not nil handle' do
      it 'should return the handle' do
        message = build_message(cbor)
        message.handle.should == 'alice.test'
      end
    end
  end
end
