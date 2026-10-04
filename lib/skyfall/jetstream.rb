# frozen_string_literal: true

require_relative 'stream'

require 'json'
require 'time'
require 'uri'

module Skyfall

  #
  # Client of a Jetstream service (JSON-based firehose).
  #
  # This is an equivalent of {Skyfall::Firehose} for Jetstream sources, mirroring its API.
  # It returns messages as instances of subclasses of {Skyfall::Jetstream::Message}, which
  # are generally equivalent to the respective {Skyfall::Firehose::Message} variants as much
  # as possible.
  #
  # To connect to a Jetstream websocket, you need to:
  #
  # * create an instance of {Skyfall::Jetstream}, passing it the hostname/URL of the server,
  #   and optionally parameters such as cursor or collection/DID filters
  # * set up callbacks to be run when connecting, disconnecting, when a message is received etc.
  #   (you need to set at least a message handler)
  # * call {#connect} to start the connection
  # * handle the received messages
  #
  # @example
  #   client = Skyfall::Jetstream.new('jetstream2.us-east.bsky.network', {
  #     wanted_collections: 'app.bsky.feed.post',
  #     wanted_dids: @dids
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

  class Jetstream < Stream

    # Current cursor (time in microseconds of the last seen message, or a
    # sequential number on a v2 server using the v1 compatibility API).
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
    #   cursor from which to resume (seq number or time in microseconds)
    #
    # @option params [Array<String>] :wanted_dids
    #   DID filter to pass to the server (`:wantedDids` or `:dids` is also accepted);
    #   value should be a DID string or an array of those
    #
    # @option params [Array<String, Symbol>] :wanted_collections
    #   collection filter to pass to the server (`:wantedCollections` or `:collections` is also accepted);
    #   value should be an NSID string or a symbol shorthand, or an array of those
    #
    # @raise [ArgumentError] if the server parameter or the options are invalid
    #
    def initialize(server, params = {})
      require_relative 'jetstream/message'
      super(server)

      @params = check_params(params)
      @cursor = @params.delete(:cursor)
      @root_url = ensure_empty_path(@root_url)
    end


    protected

    # Returns the full URL of the websocket endpoint to connect to.
    # @return [String]

    def build_websocket_url
      params = @cursor ? @params.merge(cursor: @cursor) : @params
      query = URI.encode_www_form(params)

      @root_url + "/subscribe" + (query.length > 0 ? "?#{query}" : '')
    end

    # Processes a single message received from the websocket. Passes the received data to the
    # {#on_raw_message} handler, builds a {Skyfall::Jetstream::Message} object, and passes it to
    # the {#on_message} handler (if defined). Also updates the {#cursor} to the `cursor` or `time_us`
    # value of this message (note: this is skipped if {#on_message} is not set).
    #
    # @param msg
    #   {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/API/MessageEvent Faye::WebSocket::API::MessageEvent}
    # @return [nil]

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        jet_message = Jetstream::Message.new(data)
        @cursor = jet_message.cursor
        @handlers[:message].call(jet_message)
      else
        @cursor = nil
      end
    end


    private

    def check_params(params)
      params ||= {}
      processed = {}

      raise ArgumentError.new("Params should be a hash") unless params.is_a?(Hash)

      params.each do |k, v|
        k = normalize_params_key(k)
        k, v = check_option(k, v)
        processed[k] = v
      end

      processed
    end

    def normalize_params_key(key)
      if key.is_a?(Symbol)
        key = key.to_s
      elsif !key.is_a?(String)
        raise ArgumentError.new("Invalid params key: #{key.inspect}")
      end

      key.gsub(/_([a-zA-Z])/) { $1.upcase }.to_sym
    end

    def check_option(k, v)
      case k
      when :collections, :wantedCollections
        [:wantedCollections, check_wanted_collections(v)]
      when :dids, :wantedDids
        [:wantedDids, check_wanted_dids(v)]
      when :cursor
        [:cursor, check_cursor(v)]
      when :compress, :requireHello
        raise ArgumentError.new("Skyfall::Jetstream doesn't support the #{k.inspect} option yet")
      when :kinds
        raise ArgumentError.new("The :kinds option is only supported in Jetstream v2")
      else
        raise ArgumentError.new("Unknown option: #{k.inspect}")
      end
    end

    def check_wanted_collections(list)
      list = [list] unless list.is_a?(Array)
      list.map { |c| check_collection_param(c) }
    end

    def check_collection_param(value)
      if value.is_a?(String)
        # TODO: more validation
        value
      elsif value.is_a?(Symbol)
        Collection.from_short_code(value) or raise ArgumentError.new("Unknown collection symbol: #{value.inspect}")
      else
        raise ArgumentError.new("Invalid collection argument: #{value.inspect}")
      end
    end

    def check_wanted_dids(value)
      list = value.is_a?(Array) ? value : [value]

      list.each do |did|
        unless did.is_a?(String) && did =~ /\Adid:[a-z]+:/
          raise ArgumentError.new("Invalid DID argument: #{did.inspect}")
        end
      end

      # TODO: more validation
      list
    end

    def check_cursor(cursor)
      cursor&.to_i
    end
  end
end
