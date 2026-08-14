require_relative 'ex_invalid_message'

describe Skyfall::Firehose::SyncMessage do
  let(:cbor) { cbor_sequence(*data) }
  let(:blocks) { File.binread(File.expand_path("../fixtures/attie.car", __dir__)) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#sync' },
    {
      'seq' => 5555,
      'did' => 'did:plc:foobar',
      'blocks' => blocks,
      'rev' => '3me4sottxa22d',
      'time' => '2025-04-01T00:00:00Z'
    }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(seq did blocks rev time).each do |field|
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
    it 'should parse a sync message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::SyncMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :sync
      message.kind.should == :sync
      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'
      message.seq.should == 5555
      message.rev.should == '3me4sottxa22d'
      message.should_not be_unknown
    end

    it 'should parse the timestamp' do
      message = build_message(cbor)
      message.time.should == Time.parse('2025-04-01T00:00:00Z')
    end

    it 'should parse blocks' do
      message = build_message(cbor)

      message.blocks.should be_a(Oxygene::CARArchive)
      message.blocks.roots.length.should == 1
      message.blocks.roots[0].to_s.should == "bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra"
    end

    it 'should work when created using the SyncMessage constructor' do
      message = Skyfall::Firehose::SyncMessage.new(cbor)
      message.should be_a(Skyfall::Firehose::SyncMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Firehose::AccountMessage.new(cbor) }.to raise_error(Skyfall::DecodeError)
    end

    it 'should have an operations field that returns []' do
      message = build_message(cbor)
      message.operations.should == []
    end
  end
end
