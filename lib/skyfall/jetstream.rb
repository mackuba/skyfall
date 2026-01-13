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
  # * create an instance of Jetstream, passing it the hostname/URL of the server, and optionally
  #   parameters such as cursor or collection/DID filters
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

    # Current cursor (time of the last seen message)
    # @return [Integer, nil]
    attr_accessor :cursor

    #
    # @param server [String] Address of the server to connect to.
    #   Expects a string with either just a hostname, or a ws:// or wss:// URL with no path.
    # @param params [Hash] options, see below:
    #
    # @option params [Integer] :cursor
    #   cursor from which to resume
    #
    # @option params [Array<String>] :wanted_dids
    #   DID filter to pass to the server (`:wantedDids` is also accepted);
    #   value should be a DID string or an array of those
    #
    # @option params [Array<String, Symbol>] :wanted_collections
    #   collection filter to pass to the server (`:wantedCollections` is also accepted);
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
    # the {#on_message} handler (if defined). Also updates the {#cursor} to this message's
    # microsecond timestamp (note: this is skipped if {#on_message} is not set).
    #
    # @param msg
    #   {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/API/MessageEvent Faye::WebSocket::API::MessageEvent}
    # @return [nil]

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        jet_message = Message.new(data)
        @cursor = jet_message.time_us
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
        next if v.nil?

        if k.is_a?(Symbol)
          k = k.to_s
        elsif !k.is_a?(String)
          raise ArgumentError.new("Invalid params key: #{k.inspect}")
        end

        k = k.gsub(/_([a-zA-Z])/) { $1.upcase }.to_sym
        processed[k] = check_option(k, v)
      end

      processed
    end

    def check_option(k, v)
      case k
      when :wantedCollections
        check_wanted_collections(v)
      when :wantedDids
        check_wanted_dids(v)
      when :cursor
        check_cursor(v)
      when :compress, :requireHello
        raise ArgumentError.new("Skyfall::Jetstream doesn't support the #{k.inspect} option yet")
      else
        raise ArgumentError.new("Unknown option: #{k.inspect}")
      end
    end

    def check_wanted_collections(list)
      list = [list] unless list.is_a?(Array)

      list.map do |c|
        if c.is_a?(String)
          # TODO: more validation
          c
        elsif c.is_a?(Symbol)
          Collection.from_short_code(c) or raise ArgumentError.new("Unknown collection symbol: #{c.inspect}")
        else
          raise ArgumentError.new("Invalid collection argument: #{c.inspect}")
        end
      end
    end

    def check_wanted_dids(list)
      list = [list] unless list.is_a?(Array)

      if x = list.detect { |c| !c.is_a?(String) || c !~ /\Adid:[a-z]+:/ }
        raise ArgumentError.new("Invalid DID argument: #{x.inspect}")
      end

      # TODO: more validation
      list
    end

    def check_cursor(cursor)
      cursor.to_i
    end
  end
end
