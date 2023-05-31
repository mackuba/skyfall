require_relative 'car_archive'
require_relative 'cid'
require_relative 'errors'
require_relative 'extensions'
require_relative 'operation'

require 'cbor'
require 'time'

module Skyfall
  class WebsocketMessage
    using Skyfall::Extensions

    attr_reader :type, :repo, :time, :seq, :commit, :blocks, :operations

    def initialize(data)
      objects = CBOR.decode_sequence(data)
      raise DecodeError.new("Invalid number of objects: #{objects.length}") unless objects.length == 2

      @type_object, @data_object = objects
      raise DecodeError.new("Invalid object type: #{@type_object}") unless @type_object.is_a?(Hash)
      raise DecodeError.new("Invalid object type: #{@data_object}") unless @data_object.is_a?(Hash)
      raise DecodeError.new("Missing data: #{@type_object}") unless @type_object['op'] && @type_object['t']
      raise DecodeError.new("Invalid message type: #{@type_object['t']}") unless @type_object['t'].start_with?('#')
      raise UnsupportedError.new("Unexpected CBOR object: #{@type_object}") unless @type_object['op'] == 1

      @type = @type_object['t'][1..-1].to_sym

      @repo = @data_object['repo']
      @time = Time.parse(@data_object['time'])
      @seq = @data_object['seq']

      return unless @type == :commit

      @commit = CID.from_cbor_tag(@data_object['commit'])
      @blocks = CarArchive.new(@data_object['blocks'])

      @operations = @data_object['ops'].map { |op|
        cid = op['cid'] && CID.from_cbor_tag(op['cid'])
        path = op['path']
        action = op['action']
        record = cid && @blocks.sections.detect { |s| s.cid == cid }.body

        Operation.new(@repo, path, action, cid, record)
      }
    end
  end
end
