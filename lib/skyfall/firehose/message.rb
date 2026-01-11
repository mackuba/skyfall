require_relative '../errors'
require_relative '../extensions'
require_relative '../firehose'

require 'cbor'
require 'time'

module Skyfall

  # @abstract
  # Abstract base class representing a CBOR firehose message.
  #
  # Actual messages are returned as instances of one of the subclasses of this class,
  # depending on the type of message, most commonly as {Skyfall::Firehose::CommitMessage}.
  #
  # The {new} method is overridden here so that it can be called with a binary data message
  # from the websocket, and it parses the type from the appropriate frame and builds an
  # instance of a matching subclass.
  # 
  # You normally don't need to call this class directly, unless you're building a custom
  # subclass of {Skyfall::Stream}, or reading raw data packets from the websocket through
  # the {Skyfall::Stream#on_raw_message} event handler.

  class Firehose::Message
    using Skyfall::Extensions

    require_relative 'account_message'
    require_relative 'commit_message'
    require_relative 'identity_message'
    require_relative 'info_message'
    require_relative 'labels_message'
    require_relative 'sync_message'
    require_relative 'unknown_message'

    # Type of the message (e.g. `:commit`, `:identity` etc.)
    # @return [Symbol]
    attr_reader :type

    # DID of the account (repo) that the event is sent by.
    # @return [String, nil]
    attr_reader :did

    # Sequential number of the message, to be used as a cursor when reconnecting.
    # @return [Integer, nil]
    attr_reader :seq

    alias repo did
    alias kind type

    # First of the two CBOR objects forming the message payload, which mostly just includes the type field.
    # @api private
    # @return [Hash]
    attr_reader :type_object

    # Second of the two CBOR objects forming the message payload, which contains the rest of the data.
    # @api private
    # @return [Hash]
    attr_reader :data_object

    #
    # Parses the CBOR objects from the binary data and returns an instance of an appropriate subclass.
    # 
    # {Skyfall::Firehose::UnknownMessage} is returned if the message type is not recognized.
    #
    # @param data [String] binary payload of a firehose websocket message
    # @return [Skyfall::Firehose::Message]
    # @raise [Skyfall::DecodeError] if the structure of the message is invalid
    # @raise [Skyfall::UnsupportedError] if the message has an unknown future version
    # @raise [Skyfall::SubscriptionError] if the data contains an error message from the server
    #
    def self.new(data)
      type_object, data_object = decode_cbor_objects(data)

      message_class = case type_object['t']
        when '#account'   then Firehose::AccountMessage
        when '#commit'    then Firehose::CommitMessage
        when '#identity'  then Firehose::IdentityMessage
        when '#info'      then Firehose::InfoMessage
        when '#labels'    then Firehose::LabelsMessage
        when '#sync'      then Firehose::SyncMessage
        else Firehose::UnknownMessage
      end

      message = message_class.allocate
      message.send(:initialize, type_object, data_object)
      message
    end

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    #
    def initialize(type_object, data_object)
      @type_object = type_object
      @data_object = data_object

      @type = @type_object['t'][1..-1].to_sym
      @did = @data_object['repo'] || @data_object['did']
      @seq = @data_object['seq']
    end

    #
    # List of operations on records included in the message. Only `#commit` messages include
    # operations, but for convenience the method is declared here and returns an empty array
    # in other messages.
    # @return [Array<Firehose::Operation>]
    #
    def operations
      []
    end

    #
    # @return [Boolean] true if the message is {Firehose::UnknownMessage} (of unrecognized type)
    #
    def unknown?
      self.is_a?(Firehose::UnknownMessage)
    end

    #
    # Timestamp decoded from the message.
    #
    # Note: this represents the time when the message was emitted from the original PDS, which
    # might differ a lot from the `created_at` time saved in the record data, e.g. if user's local
    # time is set incorrectly, or if an archive of existing posts was imported from another platform.
    #
    # @return [Time, nil]
    #
    def time
      @time ||= @data_object['time'] && Time.parse(@data_object['time'])
    end

    # Returns a string with a representation of the object for debugging purposes.
    # @return [String]
    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end


    protected

    # @return [Array<Symbol>] list of instance variables to be printed in the {#inspect} output
    def inspectable_variables
      instance_variables - [:@type_object, :@data_object, :@blocks]
    end

    # Checks if all required fields are set in the data object.
    # @param fields [Array<Symbol, String>] list of fields to check
    # @raise [DecodeError] if any of the fields is nil or not set
    def check_if_not_nil(*fields)
      missing = fields.select { |f| @data_object[f.to_s].nil? }

      raise DecodeError.new("Missing event details (#{missing.map(&:to_s).join(', ')})") if missing.length > 0
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

      raise DecodeError.new("Invalid object type: #{type.inspect}") unless type.is_a?(Hash)
      raise DecodeError.new("Missing data: #{type.inspect}") unless type['op'] && type['t']
      raise DecodeError.new("Invalid object type: #{type['op'].inspect}") unless type['op'].is_a?(Integer)
      raise DecodeError.new("Invalid object type: #{type['t'].inspect}") unless type['t'].is_a?(String)
      raise DecodeError.new("Invalid message type: #{type['t'].inspect}") unless type['t'].start_with?('#')
      raise UnsupportedError.new("Unsupported version: #{type['op']}") unless type['op'] == 1
      raise DecodeError.new("Invalid object type: #{data.inspect}") unless data.is_a?(Hash)

      [type, data]
    end

    private_class_method :decode_cbor_objects
  end
end
