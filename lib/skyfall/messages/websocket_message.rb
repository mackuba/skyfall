require_relative '../errors'
require_relative '../extensions'

require 'cbor'
require 'time'

module Skyfall
  class WebsocketMessage
    using Skyfall::Extensions

    require_relative 'account_message'
    require_relative 'commit_message'
    require_relative 'handle_message'
    require_relative 'identity_message'
    require_relative 'info_message'
    require_relative 'labels_message'
    require_relative 'tombstone_message'
    require_relative 'unknown_message'

    attr_reader :type_object, :data_object
    attr_reader :type, :did, :seq

    alias repo did

    def self.new(data)
      type_object, data_object = decode_cbor_objects(data)

      message_class = case type_object['t']
        when '#account' then AccountMessage
        when '#commit' then CommitMessage
        when '#handle' then HandleMessage
        when '#identity' then IdentityMessage
        when '#info' then InfoMessage
        when '#labels' then LabelsMessage
        when '#tombstone' then TombstoneMessage
        else UnknownMessage
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

    def operations
      []
    end

    def time
      @time ||= @data_object['time'] && Time.parse(@data_object['time'])
    end

    def inspectable_variables
      instance_variables - [:@type_object, :@data_object, :@blocks]
    end

    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
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

      type, data = objects

      if data['error']
        raise SubscriptionError.new(data['error'], data['message'])
      end

      raise DecodeError.new("Invalid object type: #{type}") unless type.is_a?(Hash)
      raise UnsupportedError.new("Unexpected CBOR object: #{type}") unless type['op'] == 1
      raise DecodeError.new("Missing data: #{type} #{objects.inspect}") unless type['op'] && type['t']
      raise DecodeError.new("Invalid message type: #{type['t']}") unless type['t'].start_with?('#')
      raise DecodeError.new("Invalid object type: #{data}") unless data.is_a?(Hash)

      [type, data]
    end
  end
end
