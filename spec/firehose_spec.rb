# frozen_string_literal: true

describe Skyfall::Firehose do
  it "should default to subscribe repos" do
    firehose = described_class.new("example.com")

    firehose.send(:build_websocket_url).should eq("wss://example.com/xrpc/#{Skyfall::Firehose::SUBSCRIBE_REPOS}")
  end

  it "should accept a cursor as the second argument" do
    firehose = described_class.new("example.com", 12)

    firehose.cursor.should eq(12)
    firehose.send(:build_websocket_url).should eq("wss://example.com/xrpc/#{Skyfall::Firehose::SUBSCRIBE_REPOS}?cursor=12")
  end

  it "should accept named endpoints" do
    firehose = described_class.new("example.com", :subscribe_labels)

    firehose.send(:build_websocket_url).should eq("wss://example.com/xrpc/#{Skyfall::Firehose::SUBSCRIBE_LABELS}")
  end

  it "should reject unknown endpoints" do
    expect { described_class.new("example.com", :unknown) }.to raise_error(ArgumentError)
  end

  it "should reject invalid cursor" do
    expect { described_class.new("example.com", :subscribe_repos, "abc") }.to raise_error(ArgumentError)
  end

  it "should handle messages and update cursor" do
    firehose = described_class.new("example.com")
    event = Struct.new(:data).new("payload")
    received = nil

    firehose.on_message { |msg| received = msg }

    message = mock(seq: 99)
    Skyfall::Firehose::Message.expects(:new).with("payload").returns(message)

    firehose.send(:handle_message, event)

    received.should eq(message)
    firehose.cursor.should eq(99)
  end

  it "should clear cursor when no message handler is set" do
    firehose = described_class.new("example.com")
    event = Struct.new(:data).new("payload")

    firehose.send(:handle_message, event)

    firehose.cursor.should be_nil
  end
end
