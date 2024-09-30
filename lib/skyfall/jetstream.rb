require_relative 'messages/jetstream_message'
require_relative 'stream'

require 'json'
require 'uri'

module Skyfall
  class Jetstream < Stream
    def initialize(server)
      super

      @root_url = @root_url.chomp('/')

      if URI(@root_url).path != ''
        raise ArgumentError, "Server parameter should not include any path"
      end
    end

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        jet_message = Skyfall::JetstreamMessage.new(data)
        @cursor = jet_message.seq
        @handlers[:message].call(jet_message)
      else
        @cursor = nil
      end
    end

    private

    def build_websocket_url
      @root_url + "/subscribe"
    end
  end
end
