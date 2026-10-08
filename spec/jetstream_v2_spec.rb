# frozen_string_literal: true

describe Skyfall::JetstreamV2 do
  it "should build a subscribe url without params if no params are passed" do
    stream = described_class.new("example.com")

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should accept nil params as no filters" do
    stream = described_class.new("example.com", nil)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should include params as GET query parameters" do
    stream = described_class.new("example.com", { collections: :bsky_post, cursor: 42 })

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.feed.post&cursor=42"
  end

  it "should build a subscribe url with only a cursor" do
    stream = described_class.new("example.com", cursor: 42)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=42"
  end

  it "should accept cursor param name as string" do
    stream = described_class.new("example.com", 'cursor' => 400)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=400"
  end

  it "should accept cursor value as string" do
    stream = described_class.new("example.com", cursor: '100')

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=100"
  end

  it "should omit a nil cursor" do
    stream = described_class.new("example.com", cursor: nil)
    stream.cursor.should be_nil
    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should preserve a zero cursor" do
    stream = described_class.new("example.com", cursor: 0)
    stream.cursor.should == 0
    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=0"
  end

  {
    "v1 snake_case symbols" => [:wanted_dids, :wanted_collections],
    "v1 camelCase symbols" => [:wantedDids, :wantedCollections],
    "v2 name symbols" => [:dids, :collections],
    "v1 snake_case strings" => ["wanted_dids", "wanted_collections"],
    "v1 camelCase strings" => ["wantedDids", "wantedCollections"],
    "v2 name strings" => ['dids', 'collections'],
  }.each do |key_format, param_names|
    it "should accept #{key_format} as param keys" do
      dids_key, collections_key = param_names

      params = { dids_key => "did:plc:alice", collections_key => :bsky_post }
      stream = described_class.new("example.com", params)

      expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&collections=app.bsky.feed.post"
      stream.send(:build_websocket_url).should == expected_url
    end
  end

  it "should accept mixed param key formats (but please don't do this)" do
    stream = described_class.new("example.com", {
      "wantedDids" => "did:plc:alice",
      :collections => "app.bsky.feed.post",
      "cursor" => 42
    })

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&collections=app.bsky.feed.post&cursor=42"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept dids and collections arrays using v2 names" do
    stream = described_class.new("example.com", {
      dids: ["did:plc:alice", "did:plc:bob"],
      collections: [:bsky_post, "app.bsky.feed.like"]
    })

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?" +
      "dids=did%3Aplc%3Aalice&dids=did%3Aplc%3Abob&" +
      "collections=app.bsky.feed.post&collections=app.bsky.feed.like"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple dids as repeated query parameters" do
    stream = described_class.new("example.com", dids: ["did:plc:alice", "did:web:example.com"])

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&dids=did%3Aweb%3Aexample.com"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple collections as repeated query parameters and expand shortcodes" do
    stream = described_class.new("example.com", collections: [:bsky_post, "app.bsky.feed.like", :bsky_follow])

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?" +
      "collections=app.bsky.feed.post&collections=app.bsky.feed.like&collections=app.bsky.graph.follow"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept multiple dids and collections together with a cursor" do
    stream = described_class.new("example.com", {
      dids: ["did:plc:alice", "did:plc:bob"],
      collections: [:bsky_post, :bsky_like],
      cursor: 42
    })

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?" +
      "dids=did%3Aplc%3Aalice&" +
      "dids=did%3Aplc%3Abob&" +
      "collections=app.bsky.feed.post&" +
      "collections=app.bsky.feed.like&" +
      "cursor=42"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept collection wildcard strings" do
    stream = described_class.new("example.com", collections: ['app.bsky.*', 'app.bsky.feed.*'])

    stream.send(:build_websocket_url).should ==
      "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.*&collections=app.bsky.feed.*"
  end

  it "should reject unknown params" do
    expect { described_class.new("example.com", unknown: true) }.to raise_error(ArgumentError, "Unknown option: :unknown")
  end

  it "should reject params that are not a hash" do
    [[], 'params', 42, true].each do |params|
      expect { described_class.new("example.com", params) }.to raise_error(ArgumentError, "Params should be a hash")
    end
  end

  it "should reject params keys that are not strings or symbols" do
    [nil, 42, true, false].each do |key|
      expect { described_class.new("example.com", key => 'value') }.to raise_error(
        ArgumentError, "Invalid params key: #{key.inspect}"
      )
    end
  end

  it "should reject the unsupported 'compress' option" do
    [:compress, 'compress'].each do |k|
      expect { described_class.new("example.com", k => true) }.to raise_error(
      ArgumentError, "The :compress option does not exist in Jetstream v2"
      )
    end
  end

  it "should reject the unsupported 'requireHello' option" do
    [:requireHello, "requireHello", :require_hello, "require_hello"].each do |k|
      expect { described_class.new("example.com", k => true) }.to raise_error(
        ArgumentError, "The :requireHello option does not exist in Jetstream v2"
      )
    end
  end

  it "should reject invalid dids" do
    expect { described_class.new("example.com", dids: ["lizard"]) }.to raise_error(ArgumentError)
  end

  it "should reject non-string dids" do
    [:alice, 42, true, false, nil, {}].each do |did|
      expect { described_class.new("example.com", dids: did) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )

      expect { described_class.new("example.com", dids: ["did:plc:alice", did, "did:plc:bob"]) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )
    end
  end

  it "should reject collection values that are neither symbols nor strings" do
    [42, true, false, nil, {}].each do |collection|
      expect { described_class.new("example.com", collections: collection) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )

      expect { described_class.new("example.com", collections: [:bsky_post, collection, "app.bsky.feed.like"]) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )
    end
  end

  it "should reject unknown collection shortcodes" do
    expect { described_class.new("example.com", collections: :unknown_collection) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )

    expect { described_class.new("example.com", collections: [:bsky_post, :unknown_collection]) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )
  end

  describe 'message bytes filter' do
    [:max_message_size_bytes, :maxMessageSizeBytes, 'max_message_size_bytes', 'maxMessageSizeBytes'].each do |key|
      it "should accept #{key.inspect} as a message size limit param key" do
        stream = described_class.new("example.com", key => 1_000_000)

        stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=1000000"
      end
    end

    it "should accept a message size limit as a string" do
      stream = described_class.new("example.com", max_message_size_bytes: '1000000')

      stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=1000000"
    end

    it "should accept zero and the maximum message size limit" do
      [0, 4_294_967_295].each do |size|
        stream = described_class.new("example.com", max_message_size_bytes: size)

        stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=#{size}"
      end
    end

    it "should reject an invalid message size limit" do
      [nil, -1, 4_294_967_296, 1.5, true, false, [], '', 'lizard', '100MB', '-1', '1.5', '4294967296'].each do |size|
        expect { described_class.new("example.com", max_message_size_bytes: size) }.to raise_error(
          ArgumentError, /Invalid maxMessageSizeBytes argument:/
        )
      end
    end

    it "should combine a message size limit with filters and a cursor" do
      stream = described_class.new("example.com", collections: :bsky_post, max_message_size_bytes: 1_000_000, cursor: 42)

      stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.feed.post&maxMessageSizeBytes=1000000&cursor=42"
    end
  end
end
