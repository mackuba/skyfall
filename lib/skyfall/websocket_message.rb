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

    attr_reader :type_object, :data_object, :repo, :date, :commit, :ops, :blocks, :operations

    def initialize(data)
      objects = CBOR.decode_sequence(data)
      raise DecodeError.new("Invalid number of objects: #{objects.length}") unless objects.length == 2

      @type_object, @data_object = objects
      raise DecodeError.new("Invalid object type: #{@type_object}") unless @type_object.is_a?(Hash)
      raise DecodeError.new("Invalid object type: #{@data_object}") unless @data_object.is_a?(Hash)

      @repo = @data_object['repo']
      @date = Time.parse(@data_object['time'])

      @commit = CID.from_cbor_tag(@data_object['commit'])
      @blocks = CarArchive.new(@data_object['blocks'])

      @operations = @data_object['ops'].map { |op|
        cid = op['cid'] && CID.from_cbor_tag(op['cid'])
        path = op['path']
        action = op['action']
        record = cid && @blocks.sections.detect { |s| s.cid == cid }

        Operation.new(@repo, path, action, cid, record)
      }
    end
  end
end
