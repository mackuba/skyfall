# frozen_string_literal: true

require 'json'
require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::IdentityMessage do
  include_context "jetstream v2 message"

  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#identity',
      'did' => 'did:plc:foobar',
      'seq' => 3333,
      'time' => '2023-11-14T22:16:40Z',
      'witnessedAt' => '2023-11-14T22:16:40Z',
      'identity' => { 'handle' => 'alice.test' }
    }
  end

  include_examples "invalid jetstream v2 message"
  include_examples "jetstream v2 timestamps", '2023-11-14T22:16:40Z', 1_700_000_200_000_000

  context 'with missing data' do
    it "should throw an error if identity is not a hash" do
      [[], 'identity', 42, true, false].each do |value|
        json = encode_message(data.merge('identity' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid identity object')
      end
    end

    it 'should throw an error if identity is missing' do
      data.delete('identity')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing identity object')
    end

    it 'should throw an error if identity is nil' do
      data['identity'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing identity object')
    end
  end

  context 'with valid data' do
    it 'should parse an identity message' do
      message = build_message(json)
      message.should be_a(Skyfall::JetstreamV2::IdentityMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :identity
      message.kind.should == :identity

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 3333
      message.cursor.should == 3333
      message.time_us.should == 1_700_000_200_000_000

      message.should_not be_unknown
    end

    it 'should use the outer payload metadata rather than the original relay metadata' do
      data['identity'].update('did' => 'did:plc:other', 'seq' => 9001, 'time' => '2020-01-01T00:00:00Z')
      message = build_message(json)

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 3333
      message.cursor.should == 3333
      message.time_us.should == 1_700_000_200_000_000
    end

    it 'should work when created using the IdentityMessage constructor' do
      message = Skyfall::JetstreamV2::IdentityMessage.new(json)
      message.should be_a(Skyfall::JetstreamV2::IdentityMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::JetstreamV2::AccountMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'account' message, got 'identity'/)
    end

    it 'should have an operations field that returns []' do
      message = build_message(json)
      message.operations.should == []
      message.ops.should == []
    end

    it 'should have an operation field that returns nil' do
      message = build_message(json)
      message.operation.should be_nil
      message.op.should be_nil
    end

    describe '#handle' do
      context 'with a handle present' do
        it 'should return the handle' do
          message = build_message(json)
          message.handle.should == 'alice.test'
        end
      end

      context 'with no handle' do
        before do
          data['identity'].delete('handle')
        end

        it 'should return nil' do
          message = build_message(json)
          message.handle.should be_nil
        end
      end
    end
  end
end
