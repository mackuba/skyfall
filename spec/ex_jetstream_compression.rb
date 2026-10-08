# frozen_string_literal: true

require 'zstd-ruby'

shared_examples 'a compressed Jetstream stream' do
  def compress(json, dict = dictionary)
    Zstd.compress(json, dict: dict)
  end

  it "should reject invalid :compress option values" do
    [nil, 0, 1, 'true', 'false', [], {}].each do |value|
      expect { described_class.new('example.com', compress: value) }.to raise_error(
        ArgumentError, "Invalid compress argument: #{value.inspect} (expected true or false)"
      )
    end
  end

  it "should omit compress param in the URL when disabled" do
    stream = described_class.new('example.com', compress: false)
    stream.send(:build_websocket_url).should == websocket_url
  end

  it "should decompress binary messages and update the cursor" do
    received_msg = nil
    compressed_data = compress(json)

    stream.on_message { |message| received_msg = message }
    stream.send(:handle_message, websocket_frame(compressed_data))

    received_msg.should be_a(message_class)
    received_msg.json.should == JSON.parse(json)
    received_msg.seq.should == expected_cursor
    received_msg.cursor.should == expected_cursor
    stream.cursor.should == expected_cursor
  end

  it "should pass original compressed data to on_raw_message" do
    raw_data = nil
    compressed_data = compress(json)

    stream.on_raw_message { |data| raw_data = data }
    stream.expects(:decode_message_data).never
    stream.send(:handle_message, websocket_frame(compressed_data))

    raw_data.should equal(compressed_data)
    stream.cursor.should be_nil
  end

  it "should parse uncompressed messages normally when compression is disabled" do
    stream = described_class.new('example.com', compress: false)

    received = nil
    stream.on_message { |message| received = message }

    stream.send(:handle_message, websocket_frame(json))

    received.json.should == JSON.parse(json)
    stream.cursor.should == expected_cursor
  end

  it "should decode frames whose uncompressed length is not recorded in the header" do
    received = nil
    stream.on_message { |message| received = message }

    compressor = Zstd::StreamingCompress.new(dict: dictionary)
    compressed_data = compressor.compress(json) + compressor.finish

    stream.send(:handle_message, websocket_frame(compressed_data))

    received.json.should == JSON.parse(json)
  end

  it "should report invalid compressed data as a DecodeError without advancing the cursor" do
    stream.cursor = 42
    stream.on_message { |_| raise 'Unexpected message callback' }

    expect { stream.send(:handle_message, websocket_frame('invalid')) }.to raise_error(
      Skyfall::DecodeError, /Zstd decompression failed:/
    )

    stream.cursor.should == 42
  end

  it "should reject a compressed frame using a different dictionary ID" do
    stream.on_message { |_| raise 'Unexpected message callback' }

    other_dictionary = dictionary.dup
    other_dictionary[4, 4] = [98765].pack('V')
    compressed_data = compress(json, other_dictionary)

    expect { stream.send(:handle_message, websocket_frame(compressed_data)) }.to raise_error(
      Skyfall::DecodeError, /Zstd decompression failed:/
    )
  end

  it "should reject a truncated compressed frame" do
    stream.on_message { |_| raise 'Unexpected message callback' }

    compressed_data = compress(json)[0...-1]

    expect { stream.send(:handle_message, websocket_frame(compressed_data)) }.to raise_error(
      Skyfall::DecodeError, /Zstd decompression failed:/
    )
  end
end
