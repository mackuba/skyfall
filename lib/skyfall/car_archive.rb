require_relative 'cid'
require_relative 'errors'
require_relative 'extensions'

require 'cbor'
require 'stringio'

# CAR v1: https://ipld.io/specs/transport/car/carv1/
# multicodec codes: https://github.com/multiformats/multicodec/blob/master/table.csv

module Skyfall
  class CarSection
    attr_reader :cid, :body

    def initialize(cid, body)
      @cid = cid
      @body = body
    end
  end

  class CarArchive
    using Skyfall::Extensions

    attr_reader :roots, :sections

    def initialize(data)
      @sections = []

      buffer = StringIO.new(data)
      read_header(buffer)
      read_section(buffer) until buffer.eof?
    end


    private

    def read_header(buffer)
      len = buffer.read_varint

      header_data = buffer.read(len)
      raise DecodeError.new("Header too short: #{header_data}") unless header_data.length == len

      header = CBOR.decode(header_data)
      raise UnsupportedError.new("Unexpected CAR version: #{header['version']}") unless header['version'] == 1
      @roots = header['roots'].map { |x| CID.from_cbor_tag(x) }
    end

    def read_section(buffer)
      len = buffer.read_varint

      section_data = buffer.read(len)
      raise DecodeError.new("Section too short: #{section_data}") unless section_data.length == len

      sbuffer = StringIO.new(section_data)

      version = sbuffer.read_varint
      raise UnsupportedError.new("Unexpected CID version: #{version}") unless version == 1

      codec = sbuffer.read_varint
      raise UnsupportedError.new("Unexpected CID codec: #{codec}") unless codec == 0x71  # dag-cbor

      hash = sbuffer.read_varint
      raise UnsupportedError.new("Unexpected CID hash: #{hash}") unless hash == 0x12  # sha2-256

      clen = sbuffer.read_varint
      raise UnsupportedError.new("Unexpected CID length: #{clen}") unless clen == 32

      prefix = section_data[0...sbuffer.pos]

      cid_data = sbuffer.read(clen)
      raise DecodeError.new("CID too short: #{cid_data}") unless cid_data.length == clen

      cid = CID.new(prefix + cid_data)

      body_data = sbuffer.read
      body = CBOR.decode(body_data)

      @sections << CarSection.new(cid, body)
    end
  end
end
