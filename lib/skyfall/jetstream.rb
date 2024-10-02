require_relative 'stream'

require 'json'
require 'time'
require 'uri'

module Skyfall
  class Jetstream < Stream
    def self.new(server, params = {})
      # to be removed in 0.6
      instance = self.allocate
      instance.send(:initialize, server, params)
      instance
    end

    def initialize(server, params = {})
      require_relative 'jetstream/message'
      super(server)

      @root_url = @root_url.chomp('/')

      if URI(@root_url).path != ''
        raise ArgumentError, "Server parameter should not include any path"
      end

      @params = check_params(params)
      @cursor = @params.delete(:cursor)
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
      params = @cursor ? @params.merge(cursor: @cursor) : @params
      query = URI.encode_www_form(params)

      @root_url + "/subscribe" + (query.length > 0 ? "?#{query}" : '')
    end

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

      if x = list.detect { |c| !c.is_a?(String) }
        raise ArgumentError.new("Invalid collection argument: #{x.inspect}")
      end

      # TODO: more validation
      list
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
