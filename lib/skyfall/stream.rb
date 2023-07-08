require_relative 'websocket_message'

require 'eventmachine'
require 'faye/websocket'
require 'uri'

module Skyfall
  class Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS
    }

    attr_accessor :heartbeat_timeout, :heartbeat_interval, :cursor

    def initialize(server, endpoint, cursor = nil)
      @endpoint = check_endpoint(endpoint)
      @server = check_hostname(server)
      @cursor = cursor
      @handlers = {}
      @heartbeat_mutex = Mutex.new
      @heartbeat_interval = 5
      @heartbeat_timeout = 30
      @last_update = nil
    end

    def connect
      return if @ws

      url = build_websocket_url

      @handlers[:connecting]&.call(url)

      EM.run do
        EventMachine.error_handler do |e|
          @handlers[:error]&.call(e)
        end

        @ws = Faye::WebSocket::Client.new(url)

        @ws.on(:open) do |e|
          @handlers[:connect]&.call
          @cursor = nil
        end

        @ws.on(:message) do |msg|
          data = msg.data.pack('C*')
          @handlers[:raw_message]&.call(data)

          if @handlers[:message]
            atp_message = Skyfall::WebsocketMessage.new(data)
            @cursor = atp_message.seq
            @handlers[:message].call(atp_message)
          end
        end

        @ws.on(:error) do |e|
          @handlers[:error]&.call(e)
        end

        @ws.on(:close) do |e|
          @ws = nil
          @handlers[:disconnect]&.call(e)          
        end
      end
    end

    def disconnect
      return unless EM.reactor_running?

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
