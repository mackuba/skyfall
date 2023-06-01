require_relative 'websocket_message'
require 'websocket-client-simple'

module Skyfall
  class Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS
    }

    def initialize(server, endpoint)
      @endpoint = check_endpoint(endpoint)
      @server = check_hostname(server)
      @handlers = {}
    end

    def connect
      return if @websocket

      url = "wss://#{@server}/xrpc/#{@endpoint}"
      handlers = @handlers

      @websocket = WebSocket::Client::Simple.connect(url) do |ws|
        ws.on :message do |msg|
          handlers[:raw_message]&.call(msg.data)

          if handlers[:message]
            atp_message = Skyfall::WebsocketMessage.new(msg.data)
            handlers[:message].call(atp_message)
          end
        end

        ws.on :open do
          handlers[:connect]&.call
        end

        ws.on :close do |e|
          handlers[:disconnect]&.call(e)
        end

        ws.on :error do |e|
          handlers[:error]&.call(e)
        end
      end
    end

    def disconnect
      return unless @websocket

      @websocket.close
      @websocket = nil
    end

    alias close disconnect

    def on_message(&block)
      @handlers[:message] = block
    end

    def on_raw_message(&block)
      @handlers[:raw_message] = block
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


    private

    def check_endpoint(endpoint)
      if endpoint.is_a?(String)
        raise ArgumentError("Invalid endpoint name: #{endpoint}") if endpoint.strip.empty? || !endpoint.include?('.')
      elsif endpoint.is_a?(Symbol)
        raise ArgumentError("Unknown endpoint: #{endpoint}") if NAMED_ENDPOINTS[endpoint].nil?
        endpoint = NAMED_ENDPOINTS[endpoint]
      else
        raise ArgumentError("Endpoint should be a string or a symbol")
      end
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
