require_relative 'errors'

require 'base32'

module Skyfall
  class CID
    attr_reader :data

    def self.from_cbor_tag(tag)
      data = tag.value
      raise DecodeError.new("Unexpected first byte of CID: #{data[0]}") unless data[0] == "\x00"
      CID.new(data[1..-1])
    end

    def initialize(data)
      @data = data
    end

    def to_s
      'b' + Base32.encode(@data).downcase.gsub(/=+$/, '')
    end

    def inspect
      "CID(\"#{to_s}\")"
    end

    def ==(other)
      other.is_a?(CID) && @data == other.data
    end
  end
end
