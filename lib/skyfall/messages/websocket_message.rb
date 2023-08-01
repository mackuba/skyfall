require_relative '../errors'
require_relative '../extensions'

require 'cbor'
require 'time'

module Skyfall
  class WebsocketMessage
    using Skyfall::Extensions

    require_relative 'commit_message'
    require_relative 'handle_message'

    attr_reader :type_object, :data_object
    attr_reader :type, :did, :seq

    alias repo did

    def self.new(data)
      type_object, data_object = decode_cbor_objects(data)

      message_class = case type_object['t']
        when '#commit' then CommitMessage
        when '#handle' then HandleMessage
        else WebsocketMessage
      end

      message = message_class.allocate
      message.send(:initialize, type_object, data_object)
      message
    end

    def initialize(type_object, data_object)
      @type_object = type_object
      @data_object = data_object

      @type = @type_object['t'][1..-1].to_sym
      @did = @data_object['repo'] || @data_object['did']
      @seq = @data_object['seq']
    end

    def time
      @time ||= @data_object['time'] && Time.parse(@data_object['time'])
    end

    def inspect
      keys = instance_variables - [:@type_object, :@data_object, :@blocks]
      vars = keys.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end

    private

    def self.decode_cbor_objects(data)
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
