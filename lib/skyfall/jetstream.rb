require_relative 'stream'
require 'json'
require 'uri'

module Skyfall
  class Jetstream < Stream
    def self.new(server)
      # to be removed in 0.6
      instance = self.allocate
      instance.send(:initialize, server)
      instance
    end

    def initialize(server)
      require_relative 'jetstream/message'
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
        jet_message = Message.new(data)
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