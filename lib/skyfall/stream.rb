require_relative 'messages/websocket_message'

require 'eventmachine'
require 'faye/websocket'
require 'uri'

module Skyfall
  class Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS
    }

    MAX_RECONNECT_INTERVAL = 300

    attr_accessor :heartbeat_timeout, :heartbeat_interval, :cursor, :auto_reconnect

    def initialize(server, endpoint, cursor = nil)
      @endpoint = check_endpoint(endpoint)
      @server = check_hostname(server)
      @cursor = check_cursor(cursor)
      @handlers = {}
      @auto_reconnect = true
      @connection_attempts = 0
    end

    def connect
      return if @ws

      url = build_websocket_url

      @handlers[:connecting]&.call(url)
      @engines_on = true

      EM.run do
        EventMachine.error_handler do |e|
          @handlers[:error]&.call(e)
        end

        @ws = Faye::WebSocket::Client.new(url)

        @ws.on(:open) do |e|
          @handlers[:connect]&.call
        end

        @ws.on(:message) do |msg|
          @connection_attempts = 0

          data = msg.data.pack('C*')
          @handlers[:raw_message]&.call(data)

          if @handlers[:message]
            atp_message = Skyfall::WebsocketMessage.new(data)
            @cursor = atp_message.seq
            @handlers[:message].call(atp_message)
          else
            @cursor = nil
          end
        end

        @ws.on(:error) do |e|
          @handlers[:error]&.call(e)
        end

        @ws.on(:close) do |e|
          @ws = nil

          if @auto_reconnect && @engines_on
            EM.add_timer(reconnect_delay) do
              @connection_attempts += 1
              @handlers[:reconnect]&.call
              connect
            end
          else
            @engines_on = false
            @handlers[:disconnect]&.call
            EM.stop_event_loop unless @ws
          end
        end
      end
    end

    def disconnect
      return unless EM.reactor_running?

      @engines_on = false
      EM.stop_event_loop
    end

    alias close disconnect

    def on_message(&block)
      @handlers[:message] = block
    end

    def on_raw_message(&block)
      @handlers[:raw_message] = block
    end

    def on_connecting(&block)
      @handlers[:connecting] = block
    end

    def on_connect(&block)
      @handlers[:connect] = block
    end

    def on_disconnect(&block)
      @handlers[:disconnect] = block
    end

    def on_error(&block)
      @handlers[:error] = block
    end

    def on_reconnect(&block)
      @handlers[:reconnect] = block
    end


    private

    def reconnect_delay
      if @connection_attempts == 0
        0
      else
        [2 ** (@connection_attempts - 1), MAX_RECONNECT_INTERVAL].min
      end
    end

    def build_websocket_url
      url = "wss://#{@server}/xrpc/#{@endpoint}"
      url += "?cursor=#{@cursor}" if @cursor
      url
    end

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
