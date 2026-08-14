require_relative 'ex_invalid_message'

describe Skyfall::Firehose::AccountMessage do
  let(:cbor) { cbor_sequence(*data) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#account' },
    {
      'seq' => 2222,
      'did' => 'did:plc:foobar',
      'time' => '2025-01-01T00:00:00Z',
      'active' => true
    }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(seq did time active).each do |field|
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
    it 'should parse an account message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::AccountMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :account
      message.kind.should == :account
      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'
      message.seq.should == 2222
      message.should_not be_unknown
    end

    it 'should parse the timestamp' do
      message = build_message(cbor)
      message.time.should == Time.parse('2025-01-01T00:00:00Z')
    end

    it 'should work when created using the AccountMessage constructor' do
      message = Skyfall::Firehose::AccountMessage.new(cbor)
      message.should be_a(Skyfall::Firehose::AccountMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Firehose::CommitMessage.new(cbor) }.to raise_error(Skyfall::DecodeError)
    end

    it 'should have an operations field that returns []' do
      message = build_message(cbor)
      message.operations.should == []
    end

    context 'for an active account' do
      it "should say it's active" do
        message = build_message(cbor)
        message.active?.should == true
      end

      it "should have a nil status" do
        message = build_message(cbor)
        message.status.should be_nil
      end
    end

    context 'for an inactive account' do
      before do
        data[1].update('active' => false, 'status' => 'takendown')
      end

      it "should say it's not active" do
        message = build_message(cbor)
        message.active?.should == false
      end

      it "should have a status set" do
        message = build_message(cbor)
        message.status.should == :takendown
      end
    end
  end
end
