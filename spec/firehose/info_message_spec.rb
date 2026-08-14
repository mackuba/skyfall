require_relative 'ex_invalid_message'

describe Skyfall::Firehose::InfoMessage do
  let(:cbor) { cbor_sequence(*data) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#info' },
    { 'name' => 'OutdatedCursor', 'message' => 'Old cursor' }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(name).each do |field|
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
    it 'should parse an info message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::InfoMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :info
      message.kind.should == :info
      message.should_not be_unknown

      # message.to_s.should include('OutdatedCursor')
    end

    it 'should parse the message name' do
      message = build_message(cbor)
      message.name.should == 'OutdatedCursor'
    end

    it 'should include the message name in to_s' do
      message = build_message(cbor)
      message.to_s.should include('OutdatedCursor')
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

  describe '#message' do
    context 'with nil message' do
      before do
        data[1].delete('message')
      end

      it 'should return nil' do
        message = build_message(cbor)
        message.message.should be_nil
      end
    end

    context 'with not nil message' do
      it 'should return the value' do
        message = build_message(cbor)
        message.message.should == 'Old cursor'
      end

      it 'should include the message text in to_s' do
        message = build_message(cbor)
        message.to_s.should include('Old cursor')
      end
    end
  end
end
