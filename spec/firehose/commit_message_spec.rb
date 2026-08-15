require_relative 'ex_invalid_message'

describe Skyfall::Firehose::CommitMessage do
  let(:cbor) { cbor_sequence(*data) }
  let(:blocks) { File.binread(File.expand_path("../fixtures/attie.car", __dir__)) }

  def build_message(cbor)
    Skyfall::Firehose::Message.new(cbor)
  end

  let(:data) {[
    { 'op' => 1, 't' => '#commit' },
    {
      'seq' => 1024,
      'repo' => 'did:plc:qwerty',
      'commit' => CBOR::Tagged.new(
        42, "\x00\x01q\x12 \t\xCF\xF0vKM\f \xE0$5\xA9\xED\xB5\x8B5T\xC4aH\x87\x88\xDF\x80_\xCCx\x86Z\xBB\xAE\x91".b
      ),
      'rev' => '3me4sottxa22d',
      'blocks' => blocks,
      'ops' => [{
        'cid' => CBOR::Tagged.new(
          42, "\x00\x01q\x12 g_\xBA\xB0\x93\xDE\xDBN\xEB\xD9WT\xEF\xA6l\xD3p%\xCB\x8F\xD2\x8E\x1E*\xE6xA|\xC8\x1EJ6".b
        ),
        'path' => "app.bsky.feed.post/3mt37ifa2ev2f",
        'action' => 'create'
      }],
      'time' => '2024-06-24T01:59:05.668Z'
    }
  ]}

  include_examples "invalid firehose message"

  context 'with missing data' do
    %w(seq repo commit blocks ops time rev).each do |field|
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
    it 'should parse a commit message' do
      message = build_message(cbor)
      message.should be_a(Skyfall::Firehose::CommitMessage)

      message.type_object.should == data[0]
      message.data_object.should == data[1]

      message.type.should == :commit
      message.kind.should == :commit
      message.repo.should == 'did:plc:qwerty'
      message.did.should == 'did:plc:qwerty'
      message.seq.should == 1024
      message.should_not be_unknown
    end

    it 'should parse the timestamp' do
      message = build_message(cbor)
      message.time.should == Time.parse('2024-06-24T01:59:05.668Z')
    end

    it 'should parse rev' do
      message = build_message(cbor)
      message.rev.should == '3me4sottxa22d'
    end

    it 'should parse commit' do
      message = build_message(cbor)

      message.commit.should be_a(Oxygene::CID)
      message.commit.to_s.should == 'bafyreiajz7yhms2nbqqoajbvvhw3lczvktcgcsehrdpyax6mpcdfvo5ose'

      message.cid.should equal(message.commit)
    end

    it 'should parse operations' do
      message = build_message(cbor)

      message.operations.length.should == 1
      message.operations[0].should be_a(Skyfall::Firehose::Operation)
      message.operations[0].collection.should == "app.bsky.feed.post"
      message.operations[0].rkey.should == "3mt37ifa2ev2f"
      message.operations[0].action.should == :create

      message.ops.should equal(message.operations)
    end

    it 'should parse blocks' do
      message = build_message(cbor)

      message.blocks.should be_a(Oxygene::CARArchive)
      message.blocks.roots.length.should == 1
      message.blocks.roots[0].to_s.should == "bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra"
    end

    it 'should work when created using the CommitMessage constructor' do
      message = Skyfall::Firehose::CommitMessage.new(cbor)
      message.should be_a(Skyfall::Firehose::CommitMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Firehose::AccountMessage.new(cbor) }.to raise_error(Skyfall::DecodeError)
    end
  end

  describe '#prev_data' do
    context 'with nil prevData' do
      it 'should return nil' do
        message = build_message(cbor)
        message.prev_data.should be_nil
      end
    end

    context 'with not nil prevData' do
      before do
        data[1]['prevData'] = CBOR::Tagged.new(
          42, "\x00\x01q\x12 \xF2c\x14>\xD5r\xE7n\x01E\xEBs\x18&4\nc\xBA\x9E\xE8H\xB7\xBFk*6\x92\xCFE\x92\xEA\x9F".b
        )
      end

      it 'should return a parsed CID' do
        message = build_message(cbor)
        message.prev_data.should be_a(Oxygene::CID)
        message.prev_data.to_s.should == 'bafyreihsmmkd5vls45xacrplommcmnakmo5j52ciw67wwkrwslhulexkt4'
      end
    end
  end

  describe '#since' do
    context 'with nil since' do
      it 'should return nil' do
        message = build_message(cbor)
        message.since.should be_nil
      end
    end

    context 'with not nil since' do
      before do
        data[1]['since'] = '3mt2hicadtc2e'
      end

      it 'should return the value' do
        message = build_message(cbor)
        message.since.should == '3mt2hicadtc2e'
      end
    end
  end

  describe '#raw_record_for_operation' do
    it 'should look up and decode a given record' do
      message = build_message(cbor)
      record = message.raw_record_for_operation(message.operations.first)

      record.should be_a(Hash)
      record['text'].should start_with('New Attie feature, thanks for feedback from users:')
    end

    it 'should return nil if section with given cid is not found' do
      data[1]['ops'][0]['cid'] = data[1]['commit']

      message = build_message(cbor)
      record = message.raw_record_for_operation(message.operations.first)
      record.should be_nil
    end

    it "should return nil if operation doesn't have a cid" do
      data[1]['ops'][0]['cid'] = nil

      message = build_message(cbor)
      record = message.raw_record_for_operation(message.operations.first)
      record.should be_nil
    end
  end
end
