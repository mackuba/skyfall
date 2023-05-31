require 'base32'
require 'cbor'
require 'stringio'
require 'time'

def decode_cbor_sequence(data)
  unpacker = CBOR::Unpacker.new(StringIO.new(data))
  unpacker.each.to_a
end

class Op
  attr_reader :cid, :path, :action

  def initialize(hash)
    @cid = hash['cid'] && CID.from_cbor_tag(hash['cid'])
    @path = hash['path']
    @action = hash['action']
  end
end

class CID
  attr_reader :data

  def self.from_cbor_tag(tag)
    CID.new(tag.value[1..-1])
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

class Car
  class Section
    attr_reader :cid, :body

    def initialize(cid, body)
      @cid = cid
      @body = body
    end
  end

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
    raise "Header too short: #{header_data}" unless header_data.length == len

    header = CBOR.decode(header_data)
    raise "Unexpected CAR version: #{header['version']}" unless header['version'] == 1
    @roots = header['roots'].map { |x| CID.from_cbor_tag(x) }
  end

  def read_section(buffer)
    len = read_varint(buffer)

    section_data = buffer.read(len)
    raise "Section too short: #{section_data}" unless section_data.length == len

    sbuffer = StringIO.new(section_data)

    version = read_varint(sbuffer)
    raise "Unexpected CID version: #{version}" unless version == 1

    codec = read_varint(sbuffer)
    raise "Unexpected CID codec: #{codec}" unless codec == 0x71

    hash = read_varint(sbuffer)
    raise "Unexpected CID hash: #{hash}" unless hash == 0x12

    clen = read_varint(sbuffer)
    raise "Unexpected CID length: #{clen}" unless clen == 32

    prefix = section_data[0...sbuffer.pos]

    cid_data = sbuffer.read(clen)
    raise "CID too short: #{cid_data}" unless cid_data.length == clen

    cid = CID.new(prefix + cid_data)

    body_data = sbuffer.read
    body = CBOR.decode(body_data)

    @sections << Section.new(cid, body)
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

class FirehoseEvent
  attr_reader :action, :cid, :repo, :uri, :collection, :record

  def initialize(op, repo, record)
    @action = op.action
    @cid = op.cid
    @repo = repo
    @uri = "at://#{repo}/#{op.path}"
    @collection = op.path.split('/').first
    @record = record
  end
end

class FirehoseMessage
  attr_reader :type_object, :data_object, :repo, :date, :commit, :ops, :blocks, :events

  def initialize(data)
    objects = decode_cbor_sequence(data)
    raise "Invalid number of objects: #{objects.length}" unless objects.length == 2

    @type_object, @data_object = objects
    raise "Invalid object type: #{@type_object}" unless @type_object.is_a?(Hash)
    raise "Invalid object type: #{@data_object}" unless @data_object.is_a?(Hash)
  
    @repo = @data_object['repo']
    @date = Time.parse(@data_object['time'])

    @commit = CID.from_cbor_tag(@data_object['commit'])
    @ops = @data_object['ops'].map { |o| Op.new(o) }

    @blocks = Car.new(@data_object['blocks'])

    @events = @ops.map { |o| FirehoseEvent.new(o, @repo, @blocks.sections.detect { |s| s.cid == o.cid }) }
  end
end
