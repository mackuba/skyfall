require_relative 'messages/websocket_message'
require_relative 'stream'

require 'uri'

module Skyfall
  class Firehose < Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"
    SUBSCRIBE_LABELS = "com.atproto.label.subscribeLabels"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS,
      :subscribe_labels => SUBSCRIBE_LABELS
    }

    attr_accessor :cursor

    def initialize(server, endpoint, cursor = nil)
      super(server)

      @endpoint = check_endpoint(endpoint)
      @cursor = check_cursor(cursor)
      @root_url = @root_url.chomp('/')

      if URI(@root_url).path != ''
        raise ArgumentError, "Server parameter should not include any path"
      end
    end

    def handle_message(msg)
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


    private

    def build_websocket_url
      @root_url + "/xrpc/" + @endpoint + (@cursor ? "?cursor=#{@cursor}" : "")
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
