# frozen_string_literal: true

class TestStream < Skyfall::Stream
  attr_reader :started, :stopped

  def start_heartbeat_timer
    @started = true
  end

  def stop_heartbeat_timer
    @stopped = true
  end
end

describe Skyfall::Stream do
  it "should build a root url from a hostname" do
    stream = described_class.new("example.com")

    stream.send(:build_root_url, "example.com").should eq("wss://example.com")
  end

  it "should accept ws and wss urls" do
    stream = described_class.new("ws://example.com")

    stream.send(:build_root_url, "ws://example.com").should eq("ws://example.com")
  end

  it "should reject invalid urls" do
    stream = described_class.new("wss://example.com")

    expect { stream.send(:build_root_url, "http://example.com") }.to raise_error(ArgumentError)
  end

  it "should reject non-string server values" do
    expect { described_class.new(123) }.to raise_error(ArgumentError)
  end

  it "should ensure empty paths" do
    stream = described_class.new("wss://example.com")

    expect { stream.send(:ensure_empty_path, "wss://example.com/path") }.to raise_error(ArgumentError)
  end

  it "should toggle heartbeat timer when enabled" do
    stream = TestStream.new("wss://example.com")
    stream.instance_variable_set(:@engines_on, true)
    stream.instance_variable_set(:@ws, Object.new)

    stream.check_heartbeat = true

    stream.started.should be(true)
  end

  it "should stop heartbeat timer when disabled" do
    stream = TestStream.new("wss://example.com")
    stream.instance_variable_set(:@heartbeat_timer, Object.new)
    stream.check_heartbeat = true

    stream.check_heartbeat = false

    stream.stopped.should be(true)
  end

  it "should format the version string" do
    stream = described_class.new("wss://example.com")

    stream.version_string.should eq("Skyfall/#{Skyfall::VERSION}")
  end

  it "should return an inspect string" do
    stream = described_class.new("wss://example.com")

    stream.inspect.should include("Skyfall::Stream")
  end

  it "should compute reconnect delay with backoff" do
    stream = described_class.new("wss://example.com")
    stream.instance_variable_set(:@connection_attempts, 3)

    stream.send(:reconnect_delay).should eq(4)
  end
end
