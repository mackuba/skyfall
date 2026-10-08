# frozen_string_literal: true

require_relative 'ex_jetstream_compression'

describe Skyfall::Jetstream do
  it "should build a subscribe url without params if no params are passed" do
    stream = described_class.new("example.com")

    stream.send(:build_websocket_url).should == "wss://example.com/subscribe"
  end

  it "should accept nil params as no filters" do
    stream = described_class.new("example.com", nil)

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

  it "should omit a nil cursor" do
    stream = described_class.new("example.com", cursor: nil)
    stream.cursor.should be_nil
    stream.send(:build_websocket_url).should == "wss://example.com/subscribe"
  end

  it "should preserve a zero cursor" do
    stream = described_class.new("example.com", cursor: 0)
    stream.cursor.should == 0
    stream.send(:build_websocket_url).should == "wss://example.com/subscribe?cursor=0"
  end

  {
    "snake_case symbols" => [:wanted_dids, :wanted_collections],
    "camelCase symbols" => [:wantedDids, :wantedCollections],
    "v2 name symbols" => [:dids, :collections],
    "snake_case strings" => ["wanted_dids", "wanted_collections"],
    "camelCase strings" => ["wantedDids", "wantedCollections"],
    "v2 name strings" => ['dids', 'collections'],
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

  it "should accept dids and collections arrays using v2 names on the v1 endpoint" do
    stream = described_class.new("example.com", {
      dids: ["did:plc:alice", "did:plc:bob"],
      collections: [:bsky_post, "app.bsky.feed.like"]
    })

    expected_url = "wss://example.com/subscribe?" +
      "wantedDids=did%3Aplc%3Aalice&wantedDids=did%3Aplc%3Abob&" +
      "wantedCollections=app.bsky.feed.post&wantedCollections=app.bsky.feed.like"

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

  it "should accept collection wildcard strings" do
    stream = described_class.new("example.com", collections: ['app.bsky.*', 'app.bsky.feed.*'])

    stream.send(:build_websocket_url).should ==
      "wss://example.com/subscribe?wantedCollections=app.bsky.*&wantedCollections=app.bsky.feed.*"
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

  it "should reject the unsupported 'requireHello' option" do
    [:requireHello, "requireHello", :require_hello, "require_hello"].each do |k|
      expect { described_class.new("example.com", k => true) }.to raise_error(
        ArgumentError, "Skyfall::Jetstream doesn't support the :requireHello option yet"
      )
    end
  end

  it "should reject the unsupported 'kinds' option" do
    [:kinds, 'kinds'].each do |k|
      expect { described_class.new("example.com", k => :commit) }.to raise_error(
        ArgumentError, "The :kinds option is only supported in Jetstream v2"
      )
    end
  end

  it "should reject invalid dids" do
    expect { described_class.new("example.com", wanted_dids: ["bad"]) }.to raise_error(ArgumentError)
  end

  it "should reject non-string dids" do
    [:alice, 42, true, false, nil, {}].each do |did|
      expect { described_class.new("example.com", wanted_dids: did) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )

      expect { described_class.new("example.com", wanted_dids: ["did:plc:alice", did, "did:plc:bob"]) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )
    end
  end

  it "should reject collection values that are neither symbols nor strings" do
    [42, true, false, nil, {}].each do |collection|
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

  describe 'message bytes filter' do
    [:max_message_size_bytes, :maxMessageSizeBytes, 'max_message_size_bytes', 'maxMessageSizeBytes'].each do |key|
      it "should accept #{key.inspect} as a message size limit param key" do
        stream = described_class.new("example.com", key => 1_000_000)

        stream.send(:build_websocket_url).should == "wss://example.com/subscribe?maxMessageSizeBytes=1000000"
      end
    end

    it "should accept a message size limit as a string" do
      stream = described_class.new("example.com", max_message_size_bytes: '1000000')

      stream.send(:build_websocket_url).should == "wss://example.com/subscribe?maxMessageSizeBytes=1000000"
    end

    it "should accept zero and the maximum message size limit" do
      [0, 4_294_967_295].each do |size|
        stream = described_class.new("example.com", max_message_size_bytes: size)

        stream.send(:build_websocket_url).should == "wss://example.com/subscribe?maxMessageSizeBytes=#{size}"
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
      stream = described_class.new("example.com", wanted_collections: :bsky_post, max_message_size_bytes: 1_000_000, cursor: 42)

      stream.send(:build_websocket_url).should == "wss://example.com/subscribe?wantedCollections=app.bsky.feed.post&maxMessageSizeBytes=1000000&cursor=42"
    end
  end

  describe 'compression' do
    let(:stream) { described_class.new('example.com', compress: true) }
    let(:websocket_url) { 'wss://example.com/subscribe' }
    let(:dictionary) { File.binread(File.expand_path('../data/jetstream_zstd_dictionary', __dir__)) }
    let(:message_class) { Skyfall::Jetstream::AccountMessage }
    let(:expected_cursor) { 1_700_000_100_000_000 }

    let(:json) {
      JSON.generate({
        'kind' => 'account',
        'did' => 'did:plc:foobar',
        'time_us' => 1_700_000_100_000_000,
        'account' => { 'active' => true }
      })
    }

    include_examples 'a compressed Jetstream stream'

    it "should request compression together with filters and a cursor" do
      stream = described_class.new('example.com', compress: true, collections: :bsky_post, cursor: 42)

      stream.send(:build_websocket_url).should == websocket_url + '?wantedCollections=app.bsky.feed.post&cursor=42&compress=true'
    end

    it "should bundle the legacy dictionary in the gem" do
      dictionary.unpack('V2').should == [0xEC30A437, 1_612_007_021]

      spec = Gem::Specification.load(File.expand_path('../skyfall.gemspec', __dir__))
      spec.files.should include('data/jetstream_zstd_dictionary')
    end
  end
end
