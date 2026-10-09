# frozen_string_literal: true

require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::UnknownMessage do
  include_context "jetstream v2 message"

  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#incident',
      'did' => 'did:plc:foobar',
      'seq' => 6666,
      'time' => '2023-11-14T22:18:20Z',
      'level' => 9001
    }
  end

  include_examples "invalid jetstream v2 message"
  include_examples "jetstream v2 timestamps", '2023-11-14T22:18:20Z', 1_700_000_300_000_000

  context 'with valid data' do
    it 'should parse an unknown message' do
      message = build_message(json)
      message.should be_a(Skyfall::JetstreamV2::UnknownMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :incident
      message.kind.should == :incident

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 6666
      message.cursor.should == 6666
      message.time_us.should == 1_700_000_300_000_000

      message.should be_unknown
    end

    it 'should work when created using the UnknownMessage constructor' do
      message = Skyfall::JetstreamV2::UnknownMessage.new(json)
      message.should be_a(Skyfall::JetstreamV2::UnknownMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::JetstreamV2::CommitMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, "Expected 'commit' message, got 'incident'")
    end

    it 'should throw an error when parsing a message of a different known type' do
      data['$type'] = 'network.bsky.jetstream.subscribeEvents#account'
      data['account'] = { 'active' => true }

      expect { Skyfall::JetstreamV2::UnknownMessage.new(json) }.to raise_error(
        Skyfall::DecodeError, "Expected 'unknown' message, got 'account'"
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
