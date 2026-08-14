require_relative 'ex_invalid_message'

describe Skyfall::Firehose::LabelsMessage do
  let(:cbor) { cbor_sequence(*data) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#labels' },
    {
      'seq' => 4444,
      'labels' => [
        {
          'ver' => 1,
          'src' => 'did:plc:labeller',
          'uri' => 'at://did:plc:foobar/app.bsky.feed.post/123',
          'val' => 'test',
          'cts' => '2025-03-01T00:00:00Z'
        }
      ]
    }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(seq labels).each do |field|
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
    it 'should parse a labels message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::LabelsMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :labels
      message.kind.should == :labels
      message.seq.should == 4444
      message.should_not be_unknown
    end

    it 'should parse the labels' do
      message = build_message(cbor)

      message.labels.length.should == 1
      message.labels.first.should be_a(Skyfall::Label)
      message.labels.first.value.should == 'test'
      message.labels.first.subject.should == 'at://did:plc:foobar/app.bsky.feed.post/123'
    end

    it 'should work when created using the LabelsMessage constructor' do
      message = Skyfall::Firehose::LabelsMessage.new(cbor)
      message.should be_a(Skyfall::Firehose::LabelsMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Firehose::AccountMessage.new(cbor) }.to raise_error(Skyfall::DecodeError)
    end

    it 'should have did, repo & time properties which return nil' do
      message = build_message(cbor)

      message.repo.should be_nil
      message.did.should be_nil
      message.time.should be_nil
    end

    it 'should have an operations field that returns []' do
      message = build_message(cbor)
      message.operations.should == []
    end
  end

  context 'if labels is not an array' do
    before do
      data[1]['labels'] = data[1]['labels'][0]
    end

    it 'should raise an error' do
      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, "Invalid labels field")
    end
  end
end
