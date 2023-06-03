require_relative 'errors'

require 'base32'

# CIDs in DAG-CBOR: https://ipld.io/specs/codecs/dag-cbor/spec/
# CIDs in JSON: https://ipld.io/specs/codecs/dag-json/spec/
# multibase: https://github.com/multiformats/multibase

module Skyfall
  class CID
    attr_reader :data

    def self.from_cbor_tag(tag)
      data = tag.value
      raise DecodeError.new("Unexpected first byte of CID: #{data[0]}") unless data[0] == "\x00"
      CID.new(data[1..-1])
    end

    def self.from_json(string)
      raise DecodeError.new("Unexpected CID length") unless string.length == 59
      raise DecodeError.new("Unexpected CID prefix") unless string[0] == 'b'

      data = Base32.decode(string[1..-1].upcase)
      CID.new(data)
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
