require_relative 'errors'
require 'time'

module Skyfall
  class Label
    attr_reader :data

    def initialize(data)
      @data = data

      raise DecodeError.new("Missing version: #{data}") unless data.has_key?('ver')
      raise DecodeError.new("Invalid version: #{ver}") unless ver.is_a?(Integer) && ver >= 1
      raise UnsupportedError.new("Unsupported version: #{ver}") unless ver == 1

      raise DecodeError.new("Missing source: #{data}") unless data.has_key?('src')
      raise DecodeError.new("Invalid source: #{src}") unless src.is_a?(String) && src.start_with?('did:')

      raise DecodeError.new("Missing uri: #{data}") unless data.has_key?('uri')
      raise DecodeError.new("Invalid uri: #{uri}") unless uri.is_a?(String)
      raise DecodeError.new("Invalid uri: #{uri}") unless uri.start_with?('at://') || uri.start_with?('did:')
    end

    def version
      @data['ver']
    end

    def authority
      @data['src']
    end

    def subject
      @data['uri']
    end

    def cid
      @cid ||= @data['cid'] && CID.from_json(@data['cid'])
    end

    def value
      @data['val']
    end

    def negation?
      !!@data['neg']
    end

    def created_at
      @created_at ||= Time.parse(@data['cts'])
    end

    def expires_at
      @expires_at ||= @data['exp'] && Time.parse(@data['exp'])
    end

    alias ver version
    alias src authority
    alias uri subject
    alias val value
    alias neg negation?
    alias cts created_at
    alias exp expires_at
  end
end
