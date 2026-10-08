# frozen_string_literal: true

require_relative 'ex_jetstream_compression'

describe Skyfall::JetstreamV2 do
  it "should build a subscribe url without params if no params are passed" do
    stream = Skyfall::JetstreamV2.new("example.com")

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should accept nil params as no filters" do
    stream = Skyfall::JetstreamV2.new("example.com", nil)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should include params as GET query parameters" do
    stream = Skyfall::JetstreamV2.new("example.com", { collections: :bsky_post, cursor: 42 })

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.feed.post&cursor=42"
  end

  it "should build a subscribe url with only a cursor" do
    stream = Skyfall::JetstreamV2.new("example.com", cursor: 42)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=42"
  end

  it "should accept cursor param name as string" do
    stream = Skyfall::JetstreamV2.new("example.com", 'cursor' => 400)

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=400"
  end

  it "should accept cursor value as string" do
    stream = Skyfall::JetstreamV2.new("example.com", cursor: '100')

    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?cursor=100"
  end

  it "should omit a nil cursor" do
    stream = Skyfall::JetstreamV2.new("example.com", cursor: nil)
    stream.cursor.should be_nil
    stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents"
  end

  it "should preserve a zero cursor" do
    stream = Skyfall::JetstreamV2.new("example.com", cursor: 0)
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
      stream = Skyfall::JetstreamV2.new("example.com", params)

      expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&collections=app.bsky.feed.post"
      stream.send(:build_websocket_url).should == expected_url
    end
  end

  it "should accept mixed param key formats (but please don't do this)" do
    stream = Skyfall::JetstreamV2.new("example.com", {
      "wantedDids" => "did:plc:alice",
      :collections => "app.bsky.feed.post",
      "cursor" => 42
    })

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&collections=app.bsky.feed.post&cursor=42"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept dids and collections arrays using v2 names" do
    stream = Skyfall::JetstreamV2.new("example.com", {
      dids: ["did:plc:alice", "did:plc:bob"],
      collections: [:bsky_post, "app.bsky.feed.like"]
    })

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?" +
      "dids=did%3Aplc%3Aalice&dids=did%3Aplc%3Abob&" +
      "collections=app.bsky.feed.post&collections=app.bsky.feed.like"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple dids as repeated query parameters" do
    stream = Skyfall::JetstreamV2.new("example.com", dids: ["did:plc:alice", "did:web:example.com"])

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?dids=did%3Aplc%3Aalice&dids=did%3Aweb%3Aexample.com"
    stream.send(:build_websocket_url).should == expected_url
  end

  it "should include multiple collections as repeated query parameters and expand shortcodes" do
    stream = Skyfall::JetstreamV2.new("example.com", collections: [:bsky_post, "app.bsky.feed.like", :bsky_follow])

    expected_url = "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?" +
      "collections=app.bsky.feed.post&collections=app.bsky.feed.like&collections=app.bsky.graph.follow"

    stream.send(:build_websocket_url).should == expected_url
  end

  it "should accept multiple dids and collections together with a cursor" do
    stream = Skyfall::JetstreamV2.new("example.com", {
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
    stream = Skyfall::JetstreamV2.new("example.com", collections: ['app.bsky.*', 'app.bsky.feed.*'])

    stream.send(:build_websocket_url).should ==
      "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.*&collections=app.bsky.feed.*"
  end

  it "should reject unknown params" do
    expect { Skyfall::JetstreamV2.new("example.com", unknown: true) }.to raise_error(ArgumentError, "Unknown option: :unknown")
  end

  it "should reject params that are not a hash" do
    [[], 'params', 42, true].each do |params|
      expect { Skyfall::JetstreamV2.new("example.com", params) }.to raise_error(ArgumentError, "Params should be a hash")
    end
  end

  it "should reject params keys that are not strings or symbols" do
    [nil, 42, true, false].each do |key|
      expect { Skyfall::JetstreamV2.new("example.com", key => 'value') }.to raise_error(
        ArgumentError, "Invalid params key: #{key.inspect}"
      )
    end
  end

  it "should reject the unsupported 'requireHello' option" do
    [:requireHello, "requireHello", :require_hello, "require_hello"].each do |k|
      expect { Skyfall::JetstreamV2.new("example.com", k => true) }.to raise_error(
        ArgumentError, "The :requireHello option does not exist in Jetstream v2"
      )
    end
  end

  it "should reject invalid dids" do
    expect { Skyfall::JetstreamV2.new("example.com", dids: ["lizard"]) }.to raise_error(ArgumentError)
  end

  it "should reject non-string dids" do
    [:alice, 42, true, false, nil, {}].each do |did|
      expect { Skyfall::JetstreamV2.new("example.com", dids: did) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )

      expect { Skyfall::JetstreamV2.new("example.com", dids: ["did:plc:alice", did, "did:plc:bob"]) }.to raise_error(
        ArgumentError, "Invalid DID argument: #{did.inspect}"
      )
    end
  end

  it "should reject collection values that are neither symbols nor strings" do
    [42, true, false, nil, {}].each do |collection|
      expect { Skyfall::JetstreamV2.new("example.com", collections: collection) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )

      expect { Skyfall::JetstreamV2.new("example.com", collections: [:bsky_post, collection, "app.bsky.feed.like"]) }.to raise_error(
        ArgumentError, "Invalid collection argument: #{collection.inspect}"
      )
    end
  end

  it "should reject unknown collection shortcodes" do
    expect { Skyfall::JetstreamV2.new("example.com", collections: :unknown_collection) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )

    expect { Skyfall::JetstreamV2.new("example.com", collections: [:bsky_post, :unknown_collection]) }.to raise_error(
      ArgumentError, "Unknown collection symbol: :unknown_collection"
    )
  end

  describe 'message bytes filter' do
    [:max_message_size_bytes, :maxMessageSizeBytes, 'max_message_size_bytes', 'maxMessageSizeBytes'].each do |key|
      it "should accept #{key.inspect} as a message size limit param key" do
        stream = Skyfall::JetstreamV2.new("example.com", key => 1_000_000)

        stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=1000000"
      end
    end

    it "should accept a message size limit as a string" do
      stream = Skyfall::JetstreamV2.new("example.com", max_message_size_bytes: '1000000')

      stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=1000000"
    end

    it "should accept zero and the maximum message size limit" do
      [0, 4_294_967_295].each do |size|
        stream = Skyfall::JetstreamV2.new("example.com", max_message_size_bytes: size)

        stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?maxMessageSizeBytes=#{size}"
      end
    end

    it "should reject an invalid message size limit" do
      [nil, -1, 4_294_967_296, 1.5, true, false, [], '', 'lizard', '100MB', '-1', '1.5', '4294967296'].each do |size|
        expect { Skyfall::JetstreamV2.new("example.com", max_message_size_bytes: size) }.to raise_error(
          ArgumentError, /Invalid maxMessageSizeBytes argument:/
        )
      end
    end

    it "should combine a message size limit with filters and a cursor" do
      stream = Skyfall::JetstreamV2.new("example.com", collections: :bsky_post, max_message_size_bytes: 1_000_000, cursor: 42)

      stream.send(:build_websocket_url).should == "wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents?collections=app.bsky.feed.post&maxMessageSizeBytes=1000000&cursor=42"
    end
  end

  describe 'compression' do
    let(:stream) { Skyfall::JetstreamV2.new('example.com', compress: true) }
    let(:websocket_url) { 'wss://example.com/xrpc/network.bsky.jetstream.subscribeEvents' }
    let(:message_class) { Skyfall::JetstreamV2::AccountMessage }
    let(:expected_cursor) { 2222 }
    let(:dictionary) { File.binread(File.expand_path('fixtures/jetstream_v2_dictionary', __dir__)) }

    let(:json) do
      JSON.generate({
        '$type' => 'message',
        'payload' => {
          '$type' => 'network.bsky.jetstream.subscribeEvents#account',
          'did' => 'did:plc:foobar',
          'seq' => 2222,
          'time' => '2023-11-14T22:15:00Z',
          'account' => { 'active' => true }
        }
      })
    end

    let(:dictionary_url) { 'https://example.com/xrpc/network.bsky.jetstream.getZstdDictionary' }
    let(:dictionary_headers) {{ 'Content-Type' => 'application/octet-stream', 'X-Zstd-Dictionary-Id' => '20260811' }}

    before do
      stub_request(:get, dictionary_url).to_return(body: dictionary, headers: dictionary_headers)
    end

    include_examples 'a compressed Jetstream stream'

    it "should accept string and symbol compression keys without sending adding compress param to the URL" do
      [:compress, 'compress'].each do |key|
        client = Skyfall::JetstreamV2.new('example.com', key => true, collections: :bsky_post)
        client.send(:build_websocket_url).should == websocket_url + '?collections=app.bsky.feed.post&zstdDictionary=20260811'
      end
    end

    it "should cache the dictionary and its ID across reconnections" do
      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=20260811'
      stream.cursor = 42
      stream.send(:build_websocket_url).should == websocket_url + '?cursor=42&zstdDictionary=20260811'

      expect(a_request(:get, dictionary_url)).to have_been_made.once
    end

    it "should not cache the dictionary between stream instances" do
      2.times { Skyfall::JetstreamV2.new('example.com', compress: true).send(:build_websocket_url) }

      expect(a_request(:get, dictionary_url)).to have_been_made.twice
    end

    it "should not fetch the dictionary when compression is omitted or false" do
      [nil, { compress: false }].each do |params|
        Skyfall::JetstreamV2.new('example.com', params).send(:build_websocket_url).should == websocket_url
      end

      expect(a_request(:get, dictionary_url)).not_to have_been_made
    end

    it "should request the dictionary via http: for a ws: server and preserve the port number" do
      url = 'http://localhost:6008/xrpc/network.bsky.jetstream.getZstdDictionary'

      stub_request(:get, url).to_return(body: dictionary, headers: dictionary_headers)
      client = Skyfall::JetstreamV2.new('ws://localhost:6008', compress: true)

      client.send(:build_websocket_url).should == 'ws://localhost:6008/xrpc/network.bsky.jetstream.subscribeEvents?zstdDictionary=20260811'
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "should not cache failed dictionary downloads" do
      stub_request(:get, dictionary_url)
        .to_return(status: 503)
        .then.to_return(body: dictionary, headers: dictionary_headers)

      expect { stream.send(:build_websocket_url) }.to raise_error(
        Skyfall::DictionaryError, 'Unable to fetch Jetstream zstd dictionary: HTTP 503'
      )

      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=20260811'
      expect(a_request(:get, dictionary_url)).to have_been_made.twice
    end

    it "should not cache malformed dictionaries" do
      bad_dictionaries = [
        [0xEC30A437, 0].pack('V2'),
        [0xEC30A437, 20260811].pack('V2')
      ]

      bad_dictionaries.each do |body|
        stub_request(:get, dictionary_url).to_return(body: body, headers: dictionary_headers)
        expect { stream.send(:build_websocket_url) }.to raise_error(Skyfall::DictionaryError, /Invalid Jetstream zstd dictionary/)
      end

      stub_request(:get, dictionary_url).to_return(body: dictionary, headers: dictionary_headers)
      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=20260811'
    end

    it "should use the dictionary ID from the header rather than the binary prefix" do
      stub_request(:get, dictionary_url).to_return(body: dictionary, headers: { 'X-Zstd-Dictionary-Id' => '98765' })

      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=98765'
    end

    it "should reject missing or invalid dictionary ID headers without caching the response" do
      [nil, '', '0', '-1', 'lizard', '123abc', '1.5'].each do |id|
        headers = id ? { 'X-Zstd-Dictionary-Id' => id } : {}
        stub_request(:get, dictionary_url).to_return(body: dictionary, headers: headers)

        expect { stream.send(:build_websocket_url) }.to raise_error(
          Skyfall::DictionaryError, "Invalid Jetstream zstd dictionary ID: #{id.inspect}"
        )
      end

      stub_request(:get, dictionary_url).to_return(body: dictionary, headers: dictionary_headers)
      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=20260811'
    end

    it "should propagate dictionary request timeouts without caching the failure" do
      stub_request(:get, dictionary_url).to_timeout
      expect { stream.send(:build_websocket_url) }.to raise_error(Net::OpenTimeout)

      stub_request(:get, dictionary_url).to_return(body: dictionary, headers: dictionary_headers)
      stream.send(:build_websocket_url).should == websocket_url + '?zstdDictionary=20260811'
    end
  end
end
