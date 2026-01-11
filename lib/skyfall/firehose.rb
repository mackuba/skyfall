require_relative 'stream'
require 'uri'

module Skyfall

  #
  # Client of a standard AT Protocol firehose websocket.
  #
  # This is the main Skyfall class to use to connect to a CBOR-based firehose
  # websocket endpoint like `subscribeRepos` (on a PDS or a relay).
  #
  # To connect to the firehose, you need to:
  #
  # * create an instance of {Firehose}, passing it the hostname/URL of the server,
  #   name of the endpoint (normally `:subscribe_repos`) and optionally a cursor
  # * set up callbacks to be run when connecting, disconnecting, when a message
  #   is received etc. (you need to set at least a message handler)
  # * call {#connect} to start the connection
  # * handle the received messages (instances of a {Skyfall::Firehose::Message}
  #   subclass)
  # 
  # @example
  #   client = Skyfall::Firehose.new('bsky.network', :subscribe_repos, last_cursor)
  #
  #   client.on_message do |msg|
  #     next unless msg.type == :commit
  #
  #     msg.operations.each do |op|
  #       if op.type == :bsky_post && op.action == :create
  #         puts "[#{msg.time}] #{msg.repo}: #{op.raw_record['text']}"
  #       end
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

  class Firehose < Stream

    # the main firehose endpoint on a PDS or relay
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"

    # only used with moderation services (labellers)
    SUBSCRIBE_LABELS = "com.atproto.label.subscribeLabels"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS,
      :subscribe_labels => SUBSCRIBE_LABELS
    }

    # Current cursor (seq of the last seen message)
    # @return [Integer, nil]
    attr_accessor :cursor

    #
    # @param server [String] Address of the server to connect to.
    #   Expects a string with either just a hostname, or a ws:// or wss:// URL with no path.
    #
    # @param endpoint [Symbol, String] XRPC method name.
    #   Pass either a full NSID, or a symbol shorthand from {NAMED_ENDPOINTS}
    #
    # @param cursor [Integer, String, nil] sequence number from which to resume
    #
    # @raise [ArgumentError] if any of the parameters is invalid
    #

    def initialize(server, endpoint, cursor = nil)
      require_relative 'firehose/message'
      super(server)

      @endpoint = check_endpoint(endpoint)
      @cursor = check_cursor(cursor)
      @root_url = ensure_empty_path(@root_url)
    end


    protected

    # Returns the full URL of the websocket endpoint to connect to.
    # @return [String]

    def build_websocket_url
      @root_url + "/xrpc/" + @endpoint + (@cursor ? "?cursor=#{@cursor}" : "")
    end

    # Processes a single message received from the websocket. Passes the received data to the
    # {#on_raw_message} handler, builds a {Skyfall::Firehose::Message} object, and passes it to
    # the {#on_message} handler (if defined). Also updates the {#cursor} to this message's sequence
    # number (note: this is skipped if {#on_message} is not set).
    #
    # @param msg
    #   {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/API/MessageEvent Faye::WebSocket::API::MessageEvent}
    # @return [nil]

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        atp_message = Message.new(data)
        @cursor = atp_message.seq
        @handlers[:message].call(atp_message)
      else
        @cursor = nil
      end
    end


    private

    def check_cursor(cursor)
      if cursor.nil?
        nil
      elsif cursor.is_a?(Integer) || cursor.is_a?(String) && cursor =~ /^[0-9]+$/
        cursor.to_i
      else
        raise ArgumentError, "Invalid cursor: #{cursor.inspect} - cursor must be an integer number"
      end
    end

    def check_endpoint(endpoint)
      if endpoint.is_a?(String)
        raise ArgumentError.new("Invalid endpoint name: #{endpoint}") if endpoint.strip == '' || !endpoint.include?('.')
      elsif endpoint.is_a?(Symbol)
        raise ArgumentError.new("Unknown endpoint: #{endpoint}") if NAMED_ENDPOINTS[endpoint].nil?
        endpoint = NAMED_ENDPOINTS[endpoint]
      else
        raise ArgumentError, "Endpoint should be a string or a symbol"
      end

      endpoint
    end
  end
end
