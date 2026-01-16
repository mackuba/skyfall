# frozen_string_literal: true

describe Skyfall::Jetstream do
  it "should build a subscribe url without params" do
    stream = described_class.new("example.com")

    stream.send(:build_websocket_url).should eq("wss://example.com/subscribe")
  end

  it "should include cursor and params" do
    stream = described_class.new("example.com", wanted_collections: :bsky_post, cursor: 42)

    stream.send(:build_websocket_url).should eq("wss://example.com/subscribe?wantedCollections=app.bsky.feed.post&cursor=42")
  end

  it "should reject unknown params" do
    expect { described_class.new("example.com", unknown: true) }.to raise_error(ArgumentError)
  end

  it "should reject invalid dids" do
    expect { described_class.new("example.com", wanted_dids: ["bad"]) }.to raise_error(ArgumentError)
  end

  it "should reject unsupported options" do
    expect { described_class.new("example.com", compress: true) }.to raise_error(ArgumentError)
  end

  it "should handle messages and update cursor" do
    stream = described_class.new("example.com")
    event = Struct.new(:data).new("payload")
    received = nil

    stream.on_message { |msg| received = msg }

    message = mock(time_us: 123_456)
    Skyfall::Jetstream::Message.expects(:new).with("payload").returns(message)

    stream.send(:handle_message, event)

    received.should eq(message)
    stream.cursor.should eq(123_456)
  end

  it "should clear cursor when no message handler is set" do
    stream = described_class.new("example.com")
    event = Struct.new(:data).new("payload")

    stream.send(:handle_message, event)

    stream.cursor.should be_nil
  end
end
