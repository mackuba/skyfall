# frozen_string_literal: true

require 'base64'
require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::SyncMessage do
  include_context "jetstream v2 message"

  let(:blocks) { File.binread(File.expand_path("../fixtures/attie.car", __dir__)) }
  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#sync',
      'seq' => 5555,
      'did' => 'did:plc:foobar',
      'time' => '2025-04-01T00:00:00Z',
      'witnessedAt' => '2025-04-01T00:00:00Z',
      'sync' => {
        'did' => 'did:plc:foobar',
        'seq' => 9001,
        'time' => '2025-03-31T23:59:59Z',
        'rev' => '3me4sottxa22d',
        'blocks' => { '$bytes' => Base64.strict_encode64(blocks).delete('=') }
      }
    }
  end

  include_examples "invalid jetstream v2 message"
  include_examples "jetstream v2 timestamps", '2025-04-01T00:00:00Z', 1_743_465_600_000_000

  context 'with invalid data' do
    it 'should throw an error if sync is missing' do
      data.delete('sync')
      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing sync object')
    end

    it 'should throw an error if sync is nil' do
      data['sync'] = nil
      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing sync object')
    end

    it 'should throw an error if sync is not a hash' do
      [[], 'sync', 42, true, false].each do |value|
        json = encode_message(data.merge('sync' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid sync object')
      end
    end

    %w(rev blocks).each do |field|
      it "should throw an error if sync.#{field} is missing" do
        data['sync'].delete(field)
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (sync.#{field})")
      end

      it "should throw an error if sync.#{field} is nil" do
        data['sync'][field] = nil
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (sync.#{field})")
      end
    end

    it 'should throw an error if sync.rev is not a string' do
      [[], {}, 42, true, false].each do |value|
        payload = data.merge('sync' => data['sync'].merge('rev' => value))

        expect { build_message(encode_message(payload)) }.to raise_error(
          Skyfall::DecodeError, 'Invalid sync.rev field'
        )
      end
    end

    it 'should throw an error if sync.blocks is not a hash' do
      [[], 'blocks', 42, true, false].each do |value|
        payload = data.merge('sync' => data['sync'].merge('blocks' => value))

        expect { build_message(encode_message(payload)) }.to raise_error(
          Skyfall::DecodeError, 'Invalid sync.blocks field'
        )
      end
    end

    it 'should throw an error if sync.blocks.$bytes is missing' do
      data['sync']['blocks'].delete('$bytes')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing event details (sync.blocks.$bytes)')
    end

    it 'should throw an error if sync.blocks.$bytes is nil' do
      data['sync']['blocks']['$bytes'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing event details (sync.blocks.$bytes)')
    end

    it 'should throw an error if sync.blocks.$bytes is not a string' do
      [[], {}, 42, true, false].each do |value|
        data['sync']['blocks']['$bytes'] = value

        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid sync.blocks.$bytes field')
      end
    end
  end

  context 'with valid data' do
    it 'should parse a sync message' do
      message = build_message(json)
      message.should be_a(Skyfall::JetstreamV2::SyncMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :sync
      message.kind.should == :sync

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 5555
      message.cursor.should == 5555
      message.time_us.should == 1_743_465_600_000_000

      message.rev.should == '3me4sottxa22d'
      message.should_not be_unknown
    end

    it 'should parse unpadded Base64 blocks as a CAR archive' do
      message = build_message(json)
      message.blocks.should be_a(Oxygene::CARArchive)
      message.blocks.roots.length.should == 1
      message.blocks.roots.first.to_s.should == 'bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra'
      message.blocks.should equal(message.blocks)
    end

    it 'should also parse padded Base64 blocks' do
      data['sync']['blocks']['$bytes'] = Base64.strict_encode64(blocks)
      message = build_message(json)
      message.blocks.should be_a(Oxygene::CARArchive)
      message.blocks.roots.first.to_s.should == 'bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra'
    end

    it 'should throw a DecodeError when blocks are not valid Base64' do
      data['sync']['blocks']['$bytes'] = '!not base64!'
      message = build_message(json)
      expect { message.blocks }.to raise_error(Skyfall::DecodeError, /Invalid sync blocks:/)
    end

    it 'should use the outer payload metadata rather than the original relay metadata' do
      data['sync'].update('did' => 'did:plc:other', 'seq' => 9001, 'time' => '2020-01-01T00:00:00Z')
      message = build_message(json)

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 5555
      message.cursor.should == 5555
      message.time_us.should == 1_743_465_600_000_000
    end

    it 'should work when created using the SyncMessage constructor' do
      message = Skyfall::JetstreamV2::SyncMessage.new(json)
      message.should be_a(Skyfall::JetstreamV2::SyncMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::JetstreamV2::AccountMessage.new(json) }.to raise_error(
        Skyfall::DecodeError, "Expected 'account' message, got 'sync'"
      )
    end

    it 'should have an operation field that returns nil' do
      message = build_message(json)
      message.operation.should be_nil
      message.op.should be_nil
    end

    it 'should have an operations field that returns []' do
      message = build_message(json)
      message.operations.should == []
      message.ops.should == []
    end
  end
end
