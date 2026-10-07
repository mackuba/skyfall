# frozen_string_literal: true

require 'json'
require_relative 'ex_invalid_message'

describe Skyfall::Jetstream::UnknownMessage do
  let(:json) { JSON.generate(data) }

  def build_message(json)
    Skyfall::Jetstream::Message.new(json)
  end

  let(:data) do
    {
      'kind' => 'incident',
      'did' => 'did:plc:foobar',
      'time_us' => 1_700_000_300_000_000,
      'level' => 9001
    }
  end

  include_examples "invalid jetstream message"

  context 'with valid data' do
    it 'should parse an unknown message' do
      message = build_message(json)
      message.should be_a(Skyfall::Jetstream::UnknownMessage)
      message.json.should == JSON.parse(json)

      message.should be_unknown
    end

    it 'should work when created using the UnknownMessage constructor' do
      message = Skyfall::Jetstream::UnknownMessage.new(json)
      message.should be_a(Skyfall::Jetstream::UnknownMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Jetstream::CommitMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'commit' message, got 'incident'/)
    end

    it 'should expose the included message type' do
      message = build_message(json)

      message.type.should == :incident
      message.kind.should == :incident
    end

    it 'should parse the common message fields' do
      message = build_message(json)

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 1_700_000_300_000_000
      message.cursor.should == 1_700_000_300_000_000
      message.time_us.should == 1_700_000_300_000_000

      message.time.should == Time.parse('2023-11-14T22:18:20Z')
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

    it 'should work when created using the UnknownMessage constructor' do
      message = Skyfall::Jetstream::UnknownMessage.new(json)
      message.should be_a(Skyfall::Jetstream::UnknownMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Jetstream::CommitMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'commit' message, got 'incident'/)
    end

    it "should throw an error when parsing a message of a different known type" do
      json = JSON.generate({
        'kind' => 'account',
        'did' => 'did:plc:foobar',
        'time_us' => 1_700_000_100_000_000,
        'account' => { 'active' => true }
      })

      expect { Skyfall::Jetstream::UnknownMessage.new(json) }.to raise_error(Skyfall::DecodeError)
    end
  end
end
