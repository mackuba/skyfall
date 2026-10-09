# frozen_string_literal: true

require 'json'
require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::CommitMessage do
  include_context "jetstream v2 message"

  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#commit',
      'did' => 'did:plc:qwerty',
      'seq' => 1024,
      'time' => '2023-11-14T22:13:25Z',
      'witnessedAt' => '2023-11-14T22:13:25Z',
      'rev' => '3mx3e5ky4x32n',
      'collection' => 'app.bsky.feed.post',
      'rkey' => '3mt37ifa2ev2f',
      'cid' => 'bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra',
      'operation' => 'create',
      'record' => {
        'text' => 'Hello world',
        'createdAt' => '2023-11-14T22:13:19.000Z'
      }
    }
  end

  include_examples "invalid jetstream v2 message"
  include_examples "jetstream v2 timestamps", '2023-11-14T22:13:25Z', 1_700_000_005_000_000

  context 'with missing data' do
    %w(collection rkey operation rev).each do |field|
      it "should throw an error if #{field} is missing" do
        data.delete(field)

        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /#{field}/)
      end

      it "should throw an error if #{field} is nil" do
        data[field] = nil

        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /#{field}/)
      end
    end
  end

  context 'with valid data' do
    it 'should parse a commit message' do
      message = build_message(json)
      message.should be_a(Skyfall::JetstreamV2::CommitMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :commit
      message.kind.should == :commit

      message.repo.should == 'did:plc:qwerty'
      message.did.should == 'did:plc:qwerty'

      message.seq.should == 1024
      message.cursor.should == 1024
      message.time_us.should == 1_700_000_005_000_000

      message.rev.should == '3mx3e5ky4x32n'
      message.should_not be_unknown
    end

    it 'should work when created using the CommitMessage constructor' do
      message = Skyfall::JetstreamV2::CommitMessage.new(json)
      message.should be_a(Skyfall::JetstreamV2::CommitMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::JetstreamV2::IdentityMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'identity' message, got 'commit'/)
    end

    describe '#operation' do
      it 'should return an Operation' do
        message = build_message(json)
        message.operation.should be_a(Skyfall::Jetstream::Operation)
        message.op.should equal(message.operation)
      end

      it 'should expose the operation details' do
        op = build_message(json).operation

        op.repo.should == 'did:plc:qwerty'
        op.collection.should == 'app.bsky.feed.post'
        op.rkey.should == '3mt37ifa2ev2f'
        op.action.should == :create
        op.raw_record['text'].should == 'Hello world'
      end
    end

    describe '#operations' do
      it 'should return an array with the single operation' do
        message = build_message(json)

        message.operations.length.should == 1
        message.operations[0].should equal(message.operation)
        message.ops.should == message.operations
      end
    end

    context 'with a delete operation' do
      before do
        data.update('operation' => 'delete')
        data.delete('cid')
        data.delete('record')
      end

      it 'should return a delete operation without cid or record' do
        op = build_message(json).operation

        op.action.should == :delete
        op.cid.should be_nil
        op.raw_record.should be_nil
      end
    end
  end
end
