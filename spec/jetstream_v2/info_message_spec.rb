# frozen_string_literal: true

require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::InfoMessage do
  include_context "jetstream v2 message"

  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#info',
      'name' => 'OutdatedCursor',
      'message' => 'Old cursor'
    }
  end

  context 'with invalid data' do
    it "should throw an error if name is missing" do
      data.delete('name')
      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (name)")
    end

    it "should throw an error if name is nil" do
      data['name'] = nil
      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (name)")
    end
  end

  context 'with valid data' do
    it 'should parse an info message' do
      message = build_message(json)
      message.should be_a(Skyfall::JetstreamV2::InfoMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :info
      message.kind.should == :info

      message.should_not be_unknown
    end

    it 'should parse the message name and description' do
      message = build_message(json)

      message.name.should == 'OutdatedCursor'
      message.message.should == 'Old cursor'
    end

    it 'should include the message name and description in to_s' do
      message = build_message(json)
      message.to_s.should == 'OutdatedCursor: Old cursor'
    end

    it 'should return nil for a missing or nil description and use only the name in to_s' do
      data.delete('message')

      message = build_message(encode_message(data))
      message.message.should be_nil
      message.to_s.should == 'OutdatedCursor'

      data['message'] = nil

      message = build_message(encode_message(data))
      message.message.should be_nil
      message.to_s.should == 'OutdatedCursor'
    end

    it 'should have did, repo, seq & time properties which return nil' do
      message = build_message(json)

      message.repo.should be_nil
      message.did.should be_nil

      message.seq.should be_nil
      message.cursor.should be_nil

      message.time.should be_nil
      message.time_us.should be_nil
      message.witnessed_at.should be_nil
    end

    it 'should work when created using the InfoMessage constructor' do
      message = Skyfall::JetstreamV2::InfoMessage.new(json)
      message.should be_a(Skyfall::JetstreamV2::InfoMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::JetstreamV2::AccountMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, "Expected 'account' message, got 'info'")
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
