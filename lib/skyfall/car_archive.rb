require_relative 'cid'
require_relative 'errors'

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
    attr_reader :roots, :sections

    def initialize(data)
      # @data = data
      @sections = []

      buffer = StringIO.new(data)
      read_header(buffer)
      read_section(buffer) until buffer.eof?
    end

    def read_header(buffer)
      len = read_varint(buffer)

      header_data = buffer.read(len)
      raise DecodeError.new("Header too short: #{header_data}") unless header_data.length == len

      header = CBOR.decode(header_data)
      raise UnsupportedError.new("Unexpected CAR version: #{header['version']}") unless header['version'] == 1
      @roots = header['roots'].map { |x| CID.from_cbor_tag(x) }
    end

    def read_section(buffer)
      len = read_varint(buffer)

      section_data = buffer.read(len)
      raise DecodeError.new("Section too short: #{section_data}") unless section_data.length == len

      sbuffer = StringIO.new(section_data)

      version = read_varint(sbuffer)
      raise UnsupportedError.new("Unexpected CID version: #{version}") unless version == 1

      codec = read_varint(sbuffer)
      raise UnsupportedError.new("Unexpected CID codec: #{codec}") unless codec == 0x71  # dag-cbor

      hash = read_varint(sbuffer)
      raise UnsupportedError.new("Unexpected CID hash: #{hash}") unless hash == 0x12  # sha2-256

      clen = read_varint(sbuffer)
      raise UnsupportedError.new("Unexpected CID length: #{clen}") unless clen == 32

      prefix = section_data[0...sbuffer.pos]

      cid_data = sbuffer.read(clen)
      raise DecodeError.new("CID too short: #{cid_data}") unless cid_data.length == clen

      cid = CID.new(prefix + cid_data)

      body_data = sbuffer.read
      body = CBOR.decode(body_data)

      @sections << CarSection.new(cid, body)
    end

    def read_varint(buffer)
      shift = 1
      value = 0

      loop do
        byte = buffer.readbyte
        value += byte % 128 * shift
        break if byte < 128
        shift *= 128
      end

      value
    end
  end
end
