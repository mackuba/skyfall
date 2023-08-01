require_relative '../car_archive'
require_relative '../cid'
require_relative '../errors'
require_relative '../extensions'
require_relative '../operation'

require 'cbor'
require 'time'

module Skyfall
  class WebsocketMessage
    using Skyfall::Extensions

    attr_reader :type_object, :data_object
    attr_reader :type, :repo, :seq, :operations

    def initialize(data)
      @type_object, @data_object = decode_cbor_objects(data)

      @type = @type_object['t'][1..-1].to_sym
      @operations = []

      @repo = @data_object['repo']
      @seq = @data_object['seq']

      return unless @type == :commit
    end

    def time
      @time ||= @data_object['time'] && Time.parse(@data_object['time'])
    end

    def commit
      @commit ||= @data_object['commit'] && CID.from_cbor_tag(@data_object['commit'])
    end

    def prev
      @prev ||= @data_object['prev'] && CID.from_cbor_tag(@data_object['prev'])
    end

    def blocks
      @blocks ||= CarArchive.new(@data_object['blocks'])
    end

    def operations
      @operations = @data_object['ops'].map { |op| Operation.new(self, op) }
    end

    def inspect
      keys = instance_variables - [:@type_object, :@data_object, :@blocks]
      vars = keys.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end

    private

    def decode_cbor_objects(data)
      objects = CBOR.decode_sequence(data)

      if objects.length < 2
        raise DecodeError.new("Malformed message: #{objects.inspect}")
      elsif objects.length > 2
        raise DecodeError.new("Invalid number of objects: #{objects.length}")
      end

      type_object, data_object = objects

      if data_object['error']
        raise SubscriptionError.new(data_object['error'], data_object['message'])
      end

      raise DecodeError.new("Invalid object type: #{type_object}") unless type_object.is_a?(Hash)
      raise UnsupportedError.new("Unexpected CBOR object: #{type_object}") unless type_object['op'] == 1
      raise DecodeError.new("Missing data: #{type_object} #{objects.inspect}") unless type_object['op'] && type_object['t']
      raise DecodeError.new("Invalid message type: #{type_object['t']}") unless type_object['t'].start_with?('#')

      raise DecodeError.new("Invalid object type: #{data_object}") unless data_object.is_a?(Hash)

      [type_object, data_object]
    end
  end
end
