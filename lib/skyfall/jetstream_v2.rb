# frozen_string_literal: true

require_relative 'jetstream'

require 'net/http'
require 'uri'

module Skyfall

  #
  # Client of a Jetstream v2 service (JSON-based firehose with backfill capability).
  #
  # This is a subclass of {Skyfall::Jetstream}, customizing it for the version 2 API.
  # Note: backfill API is not supported yet, only live streaming is implemented currently.
  #
  # A Jetstream v2 server should accept connections from both {Skyfall::Jetstream} and
  # {Skyfall::JetstreamV2}, since it provides a backwards-compatible implementation of the
  # v1 streaming API at the `/subscribe` endpoint; a Jetstream v1 server will only accept
  # connections from {Skyfall::Jetstream}, and using {Skyfall::JetstreamV2} with a v1 server
  # will result in an error.
  #
  # The message callback returns instances of subclasses of {Skyfall::JetstreamV2::Message}, which
  # are generally equivalent, but independent from the respective {Skyfall::Jetstream::Message} variants
  # due to the different structure of the JSON responses in the v2 API.
  #
  # Other differences from {Skyfall::Jetstream}:
  #
  # * the `kinds` option
  # * `:sync` and `:info` message types
  # * `msg.cursor` is always a sequential number
  # * Jetstream v2 can also return protocol error frames, which are represented as {Skyfall::SubscriptionError}
  #
  # To connect to a Jetstream v2 websocket, you need to:
  #
  # * create an instance of {Skyfall::JetstreamV2}, passing it the hostname/URL of the server,
  #   and optionally parameters such as cursor or collection/DID/kinds filters
  # * set up callbacks to be run when connecting, disconnecting, when a message is received etc.
  #   (you need to set at least a message handler)
  # * call {#connect} to start the connection
  # * handle the received messages
  #
  # Note: The Jetstream server starts streaming from the passed cursor *inclusively*,
  # so the first event you receive will likely be one you've already processed before.
  #
  # @example
  #   client = Skyfall::JetstreamV2.new('jetstream.us-east.bsky.network', {
  #     collections: 'app.bsky.feed.post',
  #     dids: @dids
  #   })
  #
  #   client.on_message do |msg|
  #     next unless msg.type == :commit
  #
  #     op = msg.operation
  #
  #     if op.type == :bsky_post && op.action == :create
  #       puts "[#{msg.time}] #{msg.repo}: #{op.raw_record['text']}"
  #     end
  #   end
  #
  #   client.connect
  #
  #   # You might also want to set some or all of these lifecycle callback handlers:
  #
  #   client.on_connecting { |url| puts "Connecting to #{url}..." }
  #   client.on_connect { puts "Connected" }
  #   client.on_disconnect { puts "Disconnected" }
  #   client.on_reconnect { puts "Connection lost, trying to reconnect..." }
  #   client.on_timeout { puts "Connection stalled, triggering a reconnect..." }
  #   client.on_error { |e| puts "ERROR: #{e}" }
  #
  # @note Most of the methods of this class that you might want to use are defined in {Skyfall::Stream}.
  #

  class JetstreamV2 < Jetstream

    # Current cursor (always a sequential number in the v2 API).
    #
    # @return [Integer, nil]
    #
    attr_accessor :cursor

    #
    # @param server [String] Address of the server to connect to.
    #   Expects a string with either just a hostname, or a ws:// or wss:// URL with no path.
    # @param params [Hash] options, see below:
    #
    # @option params [Integer] :cursor
    #   cursor from which to resume (a sequential number)
    #
    # @option params [String, Symbol, Array<String, Symbol>] :kinds
    #   event kind filter to pass to the server; accepts one or more of `:commit`, `:identity`,
    #   `:account` or `:sync`, empty means all event kinds are received
    #
    # @option params [String, Array<String>] :dids
    #   DID filter to pass to the server (`:wanted_dids` or `:wantedDids` is also accepted);
    #   value should be a DID string or an array of those
    #
    # @option params [String, Symbol, Array<String, Symbol>] :collections
    #   collection filter to pass to the server (`:wanted_collections` or `:wantedCollections` is also accepted);
    #   value should be: an string with a concrete NSID or a prefix and wildcard, a symbol shorthand,
    #   or an array of those
    #
    # @option params [Integer, String] :max_message_size_bytes
    #   server-side message size filter (`:maxMessageSizeBytes` is also accepted);
    #   tells the server to skip events larger than the given number of bytes in size
    #   (0 is the default and means no limit). **Note:** When compression is enabled,
    #   Jetstream v2 servers compare this against the *uncompressed* message size, while
    #   Jetstream v1 servers count the *compressed* message size.
    #
    # @option params [Boolean] :compress
    #   enable zstd compression (default: false); this option is not passed to the server in the URL,
    #   but instead makes the client fetch the current Zstd compression dictionary first and then pass
    #   its ID to the server when connecting. The dictionary is cached in memory for this stream's
    #   subsequent connections.
    #
    # @raise [ArgumentError] if the server parameter or the options are invalid
    #
    def initialize(server, params = {})
      require_relative 'jetstream_v2/message'
      super(server, params)

      collections = @params[:collections] || []
      kinds = @params[:kinds] || []

      if collections.length > 0 && kinds.length > 0 && !kinds.include?('commit')
        raise ArgumentError, "Kinds filter must include :commit if collections filter is included"
      end
    end


    protected

    # Returns the full URL of the websocket endpoint to connect to.
    # @return [String]

    def build_websocket_url
      params = @params.dup
      params[:cursor] = @cursor if @cursor

      if @compress
        fetch_zstd_dictionary unless @compression_dictionary_id
        params[:zstdDictionary] = @compression_dictionary_id
      end

      query = URI.encode_www_form(params)

      @root_url + "/xrpc/network.bsky.jetstream.subscribeEvents" + (query.length > 0 ? "?#{query}" : '')
    end

    # Processes a single message received from the websocket. Passes the received data to the
    # {#on_raw_message} handler, builds a {Skyfall::JetstreamV2::Message} object, and passes it to
    # the {#on_message} handler (if defined). Also updates the {#cursor} to this message's
    # sequence number (note: this is skipped if {#on_message} is not set).
    #
    # @param msg
    #   {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/API/MessageEvent Faye::WebSocket::API::MessageEvent}
    # @return [nil]

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        jet_message = JetstreamV2::Message.new(decode_message_data(data))
        @cursor = jet_message.cursor if jet_message.cursor
        @handlers[:message].call(jet_message)
      else
        @cursor = nil
      end
    end

    # Returns the Zstd dictionary used for decompressing messages if :compress option is enabled.
    #
    # @return [Zstd::DDict]
    # @raise [SubscriptionError] if the dictionary can't be fetched
    # @raise [DecodeError] if the dictionary or its ID is invalid

    def compression_dictionary
      fetch_zstd_dictionary unless @compression_dictionary
      @compression_dictionary
    end


    private

    def check_option(k, v)
      case k
      when :collections, :wantedCollections
        [:collections, check_wanted_collections(v)]
      when :dids, :wantedDids
        [:dids, check_wanted_dids(v)]
      when :cursor
        [:cursor, check_cursor(v)]
      when :maxMessageSizeBytes
        [:maxMessageSizeBytes, check_max_message_size_bytes(v)]
      when :kinds
        [:kinds, check_kinds(v)]
      when :compress
        [:compress, check_compress(v)]
      when :requireHello
        raise ArgumentError.new("The #{k.inspect} option does not exist in Jetstream v2")
      else
        raise ArgumentError.new("Unknown option: #{k.inspect}")
      end
    end

    def check_kinds(value)
      kinds = value.is_a?(Array) ? value : [value]

      kinds = kinds.map { |kind|
        unless (kind.is_a?(String) || kind.is_a?(Symbol)) && %w(commit identity account sync).include?(kind.to_s)
          raise ArgumentError, "Invalid event kind: #{kind.inspect}"
        end

        kind.to_s
      }

      kinds.uniq
    end

    def fetch_zstd_dictionary
      uri = URI(@root_url)
      uri.scheme = (uri.scheme == 'wss') ? 'https' : 'http'
      uri.path = '/xrpc/network.bsky.jetstream.getZstdDictionary'
      uri = URI(uri.to_s)

      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = user_agent

      opts = { use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 10 }

      response = Net::HTTP.start(uri.host, uri.port, opts) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise DictionaryError, "Unable to fetch Jetstream zstd dictionary: HTTP #{response.code}"
      end

      dictionary_id = response['X-Zstd-Dictionary-Id']

      unless dictionary_id && dictionary_id.match?(/\A[0-9]+\z/) && dictionary_id.to_i > 0
        raise DictionaryError, "Invalid Jetstream zstd dictionary ID: #{dictionary_id.inspect}"
      end

      begin
        dict = Zstd::DDict.new(response.body)
      rescue RuntimeError => e
        raise DictionaryError, "Invalid Jetstream zstd dictionary: #{e.message}"
      end

      @compression_dictionary_id = dictionary_id.to_i
      @compression_dictionary = dict
    end
  end
end
