require_relative 'websocket_message'

require 'iodine'
require 'uri'

module Skyfall
  class Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS
    }

    class Handler
      attr_reader :websocket

      def initialize(stream, callbacks)
        @stream = stream
        @callbacks = callbacks
      end

      def on_open(connection)
        @websocket = connection
        @callbacks[:connect]&.call
      end

      def on_message(connection, data)
        atp_message = Skyfall::WebsocketMessage.new(data)
        @stream.cursor = atp_message.seq

        @callbacks[:raw_message]&.call(data)
        @callbacks[:message]&.call(atp_message)
      rescue StandardError => e
        @callbacks[:error]&.call(e)
      end

      def on_close(connection)
        @websocket = nil
        @callbacks[:disconnect]&.call
      end
    end

    attr_accessor :heartbeat_timeout, :heartbeat_interval, :cursor

    def initialize(server, endpoint, cursor = nil)
      @endpoint = check_endpoint(endpoint)
      @server = check_hostname(server)
      @cursor = cursor
      @callbacks = {}
      @heartbeat_mutex = Mutex.new
      @heartbeat_interval = 5
      @heartbeat_timeout = 30
      @last_update = nil
    end

    def connect
      return if @handler

      url = build_websocket_url

      @callbacks[:connecting]&.call(url)
      @handler = Handler.new(self, @callbacks)

      Thread.new do
        Iodine.threads = 1
        Iodine.connect url: url, handler: @handler, ping: 40
        Iodine.start
      end
    end

    def disconnect
      return unless @handler && @handler.websocket

      @handler.websocket.close
      @handler = nil
    end

    alias close disconnect

    def on_message(&block)
      @callbacks[:message] = block
    end

    def on_raw_message(&block)
      @callbacks[:raw_message] = block
    end

    def on_connecting(&block)
      @callbacks[:connecting] = block
    end

    def on_connect(&block)
      @callbacks[:connect] = block
    end

    def on_disconnect(&block)
      @callbacks[:disconnect] = block
    end

    def on_error(&block)
      @callbacks[:error] = block
    end

    def on_reconnect(&block)
      @callbacks[:reconnect] = block
    end


    private

    def build_websocket_url
      url = "wss://#{@server}/xrpc/#{@endpoint}"
      url += "?cursor=#{@cursor}" if @cursor
      url
    end

    def check_endpoint(endpoint)
      if endpoint.is_a?(String)
        raise ArgumentError("Invalid endpoint name: #{endpoint}") if endpoint.strip.empty? || !endpoint.include?('.')
      elsif endpoint.is_a?(Symbol)
        raise ArgumentError("Unknown endpoint: #{endpoint}") if NAMED_ENDPOINTS[endpoint].nil?
        endpoint = NAMED_ENDPOINTS[endpoint]
      else
        raise ArgumentError("Endpoint should be a string or a symbol")
      end

      endpoint
    end

    def check_hostname(server)
      if server.is_a?(String)
        raise ArgumentError("Invalid server name: #{server}") if server.strip.empty? || server.include?('/')
      else
        raise ArgumentError("Server name should be a string")
      end

      server
    end
  end
end
