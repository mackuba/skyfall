# frozen_string_literal: true

describe Skyfall::Jetstream do
  it "should build a subscribe url without params if no params are passed" do
    stream = described_class.new("example.com")

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe"
  end

  it "should include params as GET query parameters" do
    stream = described_class.new("example.com", { wanted_collections: :bsky_post, cursor: 42 })

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe?wantedCollections=app.bsky.feed.post&cursor=42"
  end

  it "should build a subscribe url with only a cursor" do
    stream = described_class.new("example.com", cursor: 42)

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe?cursor=42"
  end

  it "should accept cursor param name as string" do
    stream = described_class.new("example.com", 'cursor' => 400)

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe?cursor=400"
  end

  it "should accept cursor value as string" do
    stream = described_class.new("example.com", cursor: '100')

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe?cursor=100"
  end

  {
    "snake_case symbols" => [:wanted_dids, :wanted_collections],
    "camelCase symbols" => [:wantedDids, :wantedCollections],
    "snake_case strings" => ["wanted_dids", "wanted_collections"],
    "camelCase strings" => ["wantedDids", "wantedCollections"]
  }.each do |key_format, param_names|
    it "should accept #{key_format} as param keys" do
      dids_key, collections_key = param_names

      params = { dids_key => "did:plc:alice", collections_key => :bsky_post }
      stream = described_class.new("example.com", params)

      expected_url = "wss://example.com/subscribe?wantedDids=did%3Aplc%3Aalice&wantedCollections=app.bsky.feed.post"
      stream.send(:build_websocket_url).should == expected_url
    end
  end

  it "should accept mixed param key formats (but please don't do this)" do
    stream = described_class.new("example.com", {
      "wantedDids" => "did:plc:alice",
      :wanted_collections => "app.bsky.feed.post",
      "cursor" => 42
    })

    expected_url = "wss://example.com/subscribe?wantedDids=did%3Aplc%3Aalice&wantedCollections=app.bsky.feed.post&cursor=42"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple dids as repeated query parameters" do
    stream = described_class.new("example.com", wanted_dids: ["did:plc:alice", "did:web:example.com"])

    expected_url = "wss://example.com/subscribe?wantedDids=did%3Aplc%3Aalice&wantedDids=did%3Aweb%3Aexample.com"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple collections as repeated query parameters and expand shortcodes" do
    stream = described_class.new("example.com", wanted_collections: [:bsky_post, "app.bsky.feed.like", :bsky_follow])

    expected_url = "wss://example.com/subscribe?" +
      "wantedCollections=app.bsky.feed.post&wantedCollections=app.bsky.feed.like&wantedCollections=app.bsky.graph.follow"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept multiple dids and collections together with a cursor" do
    stream = described_class.new("example.com", {
      wanted_dids: ["did:plc:alice", "did:plc:bob"],
      wanted_collections: [:bsky_post, :bsky_like],
      cursor: 42
    })

    expected_url = "wss://example.com/subscribe?" +
      "wantedDids=did%3Aplc%3Aalice&" +
      "wantedDids=did%3Aplc%3Abob&" +
      "wantedCollections=app.bsky.feed.post&" +
      "wantedCollections=app.bsky.feed.like&" +
      "cursor=42"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should omit params with nil value" do
    stream = described_class.new("example.com", wanted_dids: nil, wanted_collections: nil, cursor: nil)

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe"
  end

  it "should reject unknown params" do
    expect { described_class.new("example.com", unknown: true) }.to raise_error(ArgumentError, "Unknown option: :unknown")
  end

  it "should reject the unsupported 'compress' option" do
    [:compress, 'compress'].each do |k|
      expect { described_class.new("example.com", k => true) }.to raise_error(
        ArgumentError, "Skyfall::Jetstream doesn't support the :compress option yet"
      )
    end
  end

  it "should reject the unsupported 'requireHello' option" do
    [:requireHello, "requireHello", :require_hello, "require_hello"].each do |k|
      expect { described_class.new("example.com", k => true) }.to raise_error(
        ArgumentError, "Skyfall::Jetstream doesn't support the :requireHello option yet"
      )
    end
  end

  it "should reject invalid dids" do
    expect { described_class.new("example.com", wanted_dids: ["bad"]) }.to raise_error(ArgumentError)
  end

  it "should reject non-string dids" do
    [:alice, 42, true, false, {}].each do |did|
      expect { described_class.new("example.com", wanted_dids: did) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )

      expect { described_class.new("example.com", wanted_dids: ["did:plc:alice", did, "did:plc:bob"]) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )
    end
  end

  it "should reject collection values that are neither symbols nor strings" do
    [42, true, false, {}].each do |collection|
      expect { described_class.new("example.com", wanted_collections: collection) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )

      expect { described_class.new("example.com", wanted_collections: [:bsky_post, collection, "app.bsky.feed.like"]) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )
    end
  end

  it "should reject unknown collection shortcodes" do
    expect { described_class.new("example.com", wanted_collections: :unknown_collection) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )

    expect { described_class.new("example.com", wanted_collections: [:bsky_post, :unknown_collection]) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )
  end
end
